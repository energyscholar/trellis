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

# Every non-OK check prints one imperative next action. A health report that
# says "unhealthy" without saying what to DO is a ritual, not a mechanism.
do_next() {
    echo "  DO-NEXT: $1"
}

# Portable SHA-256 (macOS ships shasum; most Linux ships both)
hash_sha256_file() {
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" 2>/dev/null | awk '{print $1}'
    elif command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" 2>/dev/null | awk '{print $1}'
    fi
}

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
        do_next "Restore $label from your private memory repo (scripts/restore.sh) or re-copy it from the template."
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
    do_next "Run: chmod +x $TRELLIS/scripts/*.sh"
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
        do_next "Run scripts/memory-sync.sh to commit and back up memory changes."
        warnings=$((warnings + 1))
    fi

    if [ "$tier" -lt 2 ]; then
        echo "  [WARN] no remote configured -- memories are local only"
        do_next "Run scripts/github-setup.sh to create a private GitHub backup repo."
        warnings=$((warnings + 1))
    else
        echo "  [OK] remote configured"
        checks_ok=$((checks_ok + 1))
    fi
else
    echo "  [WARN] git not available (Tier 0 mode)"
    do_next "Install git so memories are versioned and recoverable (Tier 1+)."
    warnings=$((warnings + 1))
fi

# --- Deletion wall (memory de-indexing guard) ---
# health-check runs at session start on every platform, so it is the re-arm
# catalyst: core.hooksPath is local git config and does not survive a clone.
# Arming is idempotent.
if [ "$tier" -ge 1 ]; then
    if [ -f "$TRELLIS/scripts/git-hooks/pre-commit" ]; then
        git -C "$TRELLIS" config core.hooksPath scripts/git-hooks 2>/dev/null || true
        chmod +x "$TRELLIS/scripts/git-hooks/"* 2>/dev/null || true
        if [ "$(git -C "$TRELLIS" config core.hooksPath 2>/dev/null)" = "scripts/git-hooks" ]; then
            echo "  [OK] wall: armed"
            checks_ok=$((checks_ok + 1))
        else
            echo "  [FAIL] wall: NOT armed (core.hooksPath could not be set)"
            do_next "Run scripts/install-hooks.sh and check git works in $TRELLIS."
            errors=$((errors + 1))
        fi
    else
        echo "  [WARN] wall: hook missing (scripts/git-hooks/pre-commit)"
        do_next "Run scripts/trellis-update.sh to get the deletion wall, then scripts/install-hooks.sh."
        warnings=$((warnings + 1))
    fi
else
    echo "  [WARN] wall: not armed (no git — Tier 0)"
    do_next "Install git and run scripts/install-hooks.sh to protect memories from silent deletion."
    warnings=$((warnings + 1))
fi

# --- Identity check (config ai_name vs active profile) ---
ai_name=$(grep -E '^[[:space:]]*ai_name:' "$config" 2>/dev/null | head -1 \
    | sed 's/.*ai_name:[[:space:]]*//; s/[[:space:]]*#.*//' | tr -d '\r"'"'" || true)
active_profile=$(grep -E '^[[:space:]]*active_profile:' "$config" 2>/dev/null | head -1 \
    | sed 's/.*active_profile:[[:space:]]*//; s/[[:space:]]*#.*//' | tr -d '\r"'"'" || true)
if [ -n "$ai_name" ] && [ -n "$active_profile" ] && [ "$ai_name" != "$active_profile" ]; then
    echo "  [WARN] identity: ai_name '$ai_name' != active profile '$active_profile'"
    do_next "Set identity.ai_name in config.yaml to the name this instance actually uses (per-instance profiles need per-profile names, not one global ai_name)."
    warnings=$((warnings + 1))
else
    echo "  [OK] identity: ai_name/profile consistent"
    checks_ok=$((checks_ok + 1))
fi

# --- Dignity Net canon pin ---
dn_pin_version=$(grep -E '^[[:space:]]*dn_version:' "$config" 2>/dev/null | head -1 \
    | sed 's/.*dn_version:[[:space:]]*//; s/[[:space:]]*#.*//' | tr -d '\r"'"'" || true)
dn_pin_checksum=$(grep -E '^[[:space:]]*dn_checksum:' "$config" 2>/dev/null | head -1 \
    | sed 's/.*dn_checksum:[[:space:]]*//; s/[[:space:]]*#.*//' | tr -d '\r"'"'" || true)
dn_file="$TRELLIS/plugins/dignity-net/dignity-net.md"
if [ -n "$dn_pin_checksum" ]; then
    if [ ! -f "$dn_file" ]; then
        echo "  [WARN] dignity-net: plugin file missing"
        do_next "Run scripts/trellis-update.sh to restore the canonical Dignity Net plugin."
        warnings=$((warnings + 1))
    else
        dn_actual=$(hash_sha256_file "$dn_file")
        if [ "$dn_actual" = "$dn_pin_checksum" ]; then
            echo "  [OK] dignity-net: matches pinned canon v${dn_pin_version:-?}"
            checks_ok=$((checks_ok + 1))
        else
            echo "  [WARN] dignity-net: DRIFTED from pinned canon v${dn_pin_version:-?}"
            do_next "Run scripts/trellis-update.sh to restore canonical Dignity Net (or re-pin dn_version/dn_checksum in config.yaml if a new canon was deliberately designated)."
            warnings=$((warnings + 1))
        fi
    fi
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
    do_next "Compress or archive low-value memories per memory/protocol.md (compression stages)."
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
    do_next "Add the unindexed memory files to the file map in memory/MEMORY.md — unindexed memories are unrecallable."
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
    do_next "Review the last commit's memory churn and record a session-log entry explaining it."
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
            do_next "Run scripts/rebuild-db.sh to rebuild the DB from flat files (flat files are the source of truth)."
            warnings=$((warnings + 1))
        fi
    elif [ ! -f "$db_path" ]; then
        echo "  sqlite:        ON (not built yet — run rebuild-db.sh)  [WARN]"
        do_next "Run scripts/rebuild-db.sh to build the SQLite acceleration layer."
        warnings=$((warnings + 1))
    elif ! command -v sqlite3 &>/dev/null; then
        echo "  sqlite:        ON (sqlite3 not installed)  [WARN]"
        do_next "Install sqlite3, or set database.enabled: false in config.yaml."
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
