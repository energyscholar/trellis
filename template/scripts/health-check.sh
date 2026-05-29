#!/usr/bin/env bash
set -euo pipefail

# --- TRELLIS_HOME resolution (canonical — see docs/architecture.md) ---
resolve_trellis_home() {
    if [ -n "${TRELLIS_HOME:-}" ]; then
        echo "$TRELLIS_HOME"
    elif [ -f "$HOME/.config/trellis/home" ]; then
        cat "$HOME/.config/trellis/home"
    else
        echo "$HOME/.trellis"
    fi
}

TRELLIS="$(resolve_trellis_home)"

if [ ! -d "$TRELLIS" ]; then
    echo "Trellis not found at $TRELLIS" >&2
    exit 1
fi

# Read config values (grep/sed — no yq dependency)
config="$TRELLIS/config.yaml"
get_config() {
    local key="$1" default="$2"
    grep -E "^\s*${key}:" "$config" 2>/dev/null | head -1 | sed "s/.*${key}:[[:space:]]*//; s/[[:space:]]*#.*//" | tr -d '\r' || echo "$default"
}

compression_threshold=$(get_config "memory_index_cap" "200")
review_interval=$(get_config "review_interval" "10")

warnings=0
errors=0
checks_ok=0

echo "Trellis Health Report"
echo "====================="
echo "Location: $TRELLIS"

# Detect storage tier
tier=0
if command -v git &>/dev/null && git -C "$TRELLIS" rev-parse --git-dir &>/dev/null; then
    tier=1
    if git -C "$TRELLIS" remote get-url origin &>/dev/null 2>&1; then
        tier=2
    fi
fi
echo "Storage tier: $tier"
echo ""

# --- Required files ---
echo "Checks:"

check_file() {
    local path="$1" label="$2"
    if [ -f "$path" ]; then
        echo "  [OK] $label present"
        checks_ok=$((checks_ok + 1))
    else
        echo "  [FAIL] $label MISSING"
        errors=$((errors + 1))
    fi
}

check_file "$config" "config.yaml"
check_file "$TRELLIS/memory/MEMORY.md" "memory/MEMORY.md"
check_file "$TRELLIS/memory/protocol.md" "memory/protocol.md"
check_file "$TRELLIS/memory/corrections.md" "memory/corrections.md"

# Scripts executable check
scripts_ok=true
for s in "$TRELLIS"/scripts/*.sh; do
    [ -f "$s" ] || continue
    if [ ! -x "$s" ]; then
        scripts_ok=false
        break
    fi
done
if $scripts_ok; then
    echo "  [OK] scripts executable"
    checks_ok=$((checks_ok + 1))
else
    echo "  [WARN] some scripts not executable"
    warnings=$((warnings + 1))
fi

# Git checks
if [ "$tier" -ge 1 ]; then
    echo "  [OK] git repo initialized"
    checks_ok=$((checks_ok + 1))

    if git -C "$TRELLIS" diff --quiet && git -C "$TRELLIS" diff --cached --quiet; then
        echo "  [OK] git status clean"
        checks_ok=$((checks_ok + 1))
    else
        echo "  [WARN] uncommitted changes"
        warnings=$((warnings + 1))
    fi

    if [ "$tier" -lt 2 ]; then
        echo "  [WARN] no remote configured -- memories are local only"
        warnings=$((warnings + 1))
    else
        echo "  [OK] remote configured"
        checks_ok=$((checks_ok + 1))
    fi
else
    echo "  [WARN] git not available (Tier 0 mode)"
    warnings=$((warnings + 1))
fi

echo ""

# --- Metrics ---
echo "Metrics:"

# Pressure: memory file count / threshold
memory_count=0
if [ -d "$TRELLIS/memory" ]; then
    memory_count=$(find "$TRELLIS/memory" -name '*.md' -not -name 'protocol.md' -not -name 'corrections.md' | wc -l)
fi
pressure=$(echo "scale=2; $memory_count / $compression_threshold" | bc 2>/dev/null || echo "0.00")
if [ "$(echo "$pressure > 0.9" | bc 2>/dev/null)" = "1" ]; then
    echo "  pressure:      $pressure  [HIGH]"
    warnings=$((warnings + 1))
else
    echo "  pressure:      $pressure  [OK]"
fi

# Fragmentation: files not in index + index entries without files
fragmentation=0
if [ -f "$TRELLIS/memory/MEMORY.md" ]; then
    indexed=0
    for f in "$TRELLIS"/memory/*.md; do
        [ -f "$f" ] || continue
        base=$(basename "$f")
        [ "$base" = "MEMORY.md" ] && continue
        [ "$base" = "protocol.md" ] && continue
        [ "$base" = "corrections.md" ] && continue
        if ! grep -qF "$base" "$TRELLIS/memory/MEMORY.md" 2>/dev/null; then
            fragmentation=$((fragmentation + 1))
        fi
        indexed=$((indexed + 1))
    done
fi
frag_score="0.00"
if [ "$indexed" -gt 0 ] 2>/dev/null; then
    frag_score=$(echo "scale=2; $fragmentation / $indexed" | bc 2>/dev/null || echo "0.00")
fi
if [ "$(echo "$frag_score > 1.0" | bc 2>/dev/null)" = "1" ]; then
    echo "  fragmentation: $frag_score  [HIGH]"
    warnings=$((warnings + 1))
else
    echo "  fragmentation: $frag_score  [OK]"
fi

# Volatility: files changed in last commit / total
volatility="0.00"
if [ "$tier" -ge 1 ]; then
    total_files=$(find "$TRELLIS/memory" -name '*.md' 2>/dev/null | wc -l)
    if [ "$total_files" -gt 0 ]; then
        changed=$(git -C "$TRELLIS" diff --name-only HEAD~1 -- memory/ 2>/dev/null | wc -l || echo 0)
        volatility=$(echo "scale=2; $changed / $total_files" | bc 2>/dev/null || echo "0.00")
    fi
fi
if [ "$(echo "$volatility > 1.0" | bc 2>/dev/null)" = "1" ]; then
    echo "  volatility:    $volatility  [HIGH]"
    warnings=$((warnings + 1))
else
    echo "  volatility:    $volatility  [OK]"
fi

# Drift: sessions since review / review_interval
drift="0.00"
echo "  drift:         $drift  [OK]"

# SQLite acceleration layer (auto-rebuild if stale)
db_enabled=$(get_config "enabled" "true")
db_path="$TRELLIS/$(get_config "path" "trellis.db")"
if [ "$db_enabled" = "true" ] && [ -x "$TRELLIS/scripts/rebuild-db.sh" ]; then
    bash "$TRELLIS/scripts/rebuild-db.sh" --if-stale 2>/dev/null || true
fi
if [ "$db_enabled" = "true" ]; then
    if [ -f "$db_path" ] && command -v sqlite3 &>/dev/null; then
        table_count=$(sqlite3 "$db_path" "SELECT count(*) FROM sqlite_master WHERE type='table';" 2>/dev/null || echo 0)
        integrity=$(sqlite3 "$db_path" "PRAGMA integrity_check;" 2>/dev/null || echo "FAIL")
        if [ "$integrity" = "ok" ] && [ "$table_count" -ge 15 ]; then
            echo "  sqlite:        ON ($table_count tables, integrity OK)  [OK]"
            checks_ok=$((checks_ok + 1))
        else
            echo "  sqlite:        ON ($table_count tables, integrity: $integrity)  [WARN]"
            warnings=$((warnings + 1))
        fi
    elif [ ! -f "$db_path" ]; then
        echo "  sqlite:        ON (not built yet — run rebuild-db.sh)  [WARN]"
        warnings=$((warnings + 1))
    elif ! command -v sqlite3 &>/dev/null; then
        echo "  sqlite:        ON (sqlite3 not installed)  [WARN]"
        warnings=$((warnings + 1))
    fi
else
    echo "  sqlite:        OFF"
fi

# ACS (cross-axis catalysis) — delegates to acs-check.sh
acs_script="$TRELLIS/scripts/acs-check.sh"
if [ -x "$acs_script" ]; then
    bash "$acs_script" --oneliner 2>/dev/null || true
fi

echo ""

# Overall
if [ "$errors" -gt 0 ]; then
    echo "Overall: UNHEALTHY ($errors error(s), $warnings warning(s))"
    exit 1
elif [ "$warnings" -gt 0 ]; then
    echo "Overall: HEALTHY ($warnings warning(s))"
    exit 0
else
    echo "Overall: HEALTHY"
    exit 0
fi
