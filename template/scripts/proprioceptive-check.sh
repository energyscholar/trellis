#!/usr/bin/env bash
set -euo pipefail

# Proprioceptive check — sense internal state, recommend adjustments.
# READ-ONLY: this script does not modify any file or database.
# Fail-open: exits 0 even on errors, so sessions always proceed.

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
TODAY=$(date +%Y-%m-%d)

if [ ! -d "$TRELLIS" ]; then
    echo "PROPRIOCEPTIVE STATE — $TODAY"
    echo "Storage: TRELLIS NOT FOUND at $TRELLIS"
    echo ""
    echo "ADJUSTMENTS:"
    echo "  - [set_point:integrity_check, prov:environment] Install or configure Trellis"
    exit 0
fi

# Read config values (grep/sed — no yq dependency)
config="$TRELLIS/config.yaml"
get_config() {
    local key="$1" default="$2"
    grep -E "^\s*${key}:" "$config" 2>/dev/null | head -1 | sed "s/.*${key}:[[:space:]]*//; s/[[:space:]]*#.*//" | tr -d '\r' || echo "$default"
}

memory_index_cap=$(get_config "memory_index_cap" "200")
db_enabled=$(get_config "enabled" "true")
db_path="$TRELLIS/$(get_config "path" "trellis.db")"

# --- Determine mode: DB or flat-file ---
use_db=false
integrity="unknown"
if [ "$db_enabled" = "true" ] && [ -f "$db_path" ] && command -v sqlite3 &>/dev/null; then
    integrity=$(sqlite3 "$db_path" "PRAGMA integrity_check;" 2>&1) || integrity="fail"
    if [ "$integrity" = "ok" ]; then
        use_db=true
    fi
fi

# ============================================================================
# SENSE — gather signals
# ============================================================================

pressure="0.00"
drift="0.00"
coherence="OK"
hot_count=0
hot_corrections=""
stale_count=0
stale_list=""
prov=""
session_count=0
storage_status="OK"
acs_line=""

if $use_db; then
    # --- DB mode ---

    # Health vector
    health_row=$(sqlite3 "$db_path" \
        "SELECT COALESCE(pressure,0) || '|' || COALESCE(drift,0) FROM v_health_current;" \
        2>/dev/null) || health_row=""
    if [ -n "$health_row" ]; then
        pressure=$(echo "$health_row" | cut -d'|' -f1)
        drift=$(echo "$health_row" | cut -d'|' -f2)
    fi

    # Hot corrections (top 5 by heat)
    hot_corrections=$(sqlite3 "$db_path" \
        "SELECT '#' || number || ' ' || title FROM v_correction_heat
         WHERE heat > 0 ORDER BY heat DESC LIMIT 5;" \
        2>/dev/null) || hot_corrections=""
    if [ -n "$hot_corrections" ]; then
        hot_count=$(echo "$hot_corrections" | grep -c '.' 2>/dev/null || echo 0)
    fi

    # Stale memories
    stale_count=$(sqlite3 "$db_path" \
        "SELECT COUNT(*) FROM v_memories_stale;" \
        2>/dev/null) || stale_count=0
    if [ "$stale_count" -gt 0 ]; then
        stale_list=$(sqlite3 "$db_path" \
            "SELECT name || ' (conf=' || confidence || ')' FROM v_memories_stale
             ORDER BY confidence ASC LIMIT 5;" \
            2>/dev/null) || stale_list=""
    fi

    # Provenance (from session_events if table exists)
    prov=$(sqlite3 "$db_path" \
        "SELECT source || ':' || pct || '%' FROM v_provenance_histogram
         ORDER BY source;" \
        2>/dev/null) || prov=""

    # Session count
    session_count=$(sqlite3 "$db_path" \
        "SELECT COUNT(*) FROM sessions;" \
        2>/dev/null) || session_count=0

    storage_status="OK"

else
    # --- Flat-file fallback ---

    # Pressure: MEMORY.md line count / cap
    if [ -f "$TRELLIS/memory/MEMORY.md" ]; then
        mem_lines=$(wc -l < "$TRELLIS/memory/MEMORY.md" 2>/dev/null || echo 0)
        pressure=$(awk -v l="$mem_lines" -v c="$memory_index_cap" 'BEGIN { printf "%.2f", l/c }')
    fi

    # Drift: not computable from flat files without session review interval tracking
    drift="0.00"

    # Staleness: memory files older than 90 days (excluding MEMORY.md, protocol.md, corrections.md)
    stale_count=$(find "$TRELLIS/memory" -name '*.md' \
        -not -name 'MEMORY.md' \
        -not -name 'protocol.md' \
        -not -name 'corrections.md' \
        -mtime +90 2>/dev/null | wc -l | tr -d ' ')
    if [ "$stale_count" -gt 0 ] && [ "$stale_count" -le 5 ]; then
        stale_list=$(find "$TRELLIS/memory" -name '*.md' \
            -not -name 'MEMORY.md' \
            -not -name 'protocol.md' \
            -not -name 'corrections.md' \
            -mtime +90 -printf '%f\n' 2>/dev/null | head -5)
    fi

    # Corrections: count total corrections in corrections.md
    if [ -f "$TRELLIS/memory/corrections.md" ]; then
        hot_count=$(grep -c '^### Correction #' "$TRELLIS/memory/corrections.md" 2>/dev/null || echo 0)
        # For flat-file mode, list all as "present" but no heat ranking
        hot_corrections=""
    fi

    # Session count from session-log.md
    if [ -f "$TRELLIS/memory/session-log.md" ]; then
        session_count=$(grep -c '^| S[0-9]' "$TRELLIS/memory/session-log.md" 2>/dev/null || echo 0)
    fi

    # Provenance from session-log.md annotations
    if [ -f "$TRELLIS/memory/session-log.md" ] && [ "$session_count" -gt 0 ]; then
        prov_data=$(awk -F'|' '
            /^\| S[0-9]/ {
                for (i = 5; i <= 7; i++) {
                    nf = split($i, parts, /,/)
                    for (j = 1; j <= nf; j++) {
                        ev = parts[j]; gsub(/^[ \t]+|[ \t]+$/, "", ev)
                        if (ev == "" || ev ~ /^[-]$/) continue
                        total++
                        if (ev ~ /\(e\)/) env++
                        else if (ev ~ /\(s\)/) sys++
                        else human++
                    }
                }
            }
            END {
                if (total > 0) {
                    printf "human:%.1f%% environment:%.1f%% system:%.1f%%", \
                        100*human/total, 100*env/total, 100*sys/total
                } else {
                    print "no data yet"
                }
            }
        ' "$TRELLIS/memory/session-log.md" 2>/dev/null) || prov_data=""
        prov="$prov_data"
    fi

    # Storage status
    if [ "$db_enabled" = "true" ]; then
        if [ ! -f "$db_path" ]; then
            storage_status="NO DB"
        elif [ "$integrity" != "ok" ]; then
            storage_status="INTEGRITY FAILURE"
        fi
    else
        storage_status="flat-file only"
    fi
fi

# --- Coherence classification (awk for portability, no bc) ---
coherence=$(awk -v p="$pressure" -v d="$drift" 'BEGIN {
    if (p+0 > 0.9) print "CRITICAL"
    else if (d+0 >= 1.0) print "DEGRADED"
    else print "OK"
}')

# --- ACS one-liner ---
acs_script="$TRELLIS/scripts/acs-check.sh"
if [ -x "$acs_script" ]; then
    acs_line=$(bash "$acs_script" --oneliner 2>/dev/null) || acs_line="  acs:           -- (check failed)"
else
    acs_line="  acs:           -- (acs-check.sh not found)"
fi

# ============================================================================
# OUTPUT
# ============================================================================

echo "PROPRIOCEPTIVE STATE — $TODAY"
echo "───────────────────────────────"
printf "Coherence:    %s  p=%s d=%s\n" "$coherence" "$pressure" "$drift"

echo -n "Corrections:  $hot_count"
if $use_db && [ -n "$hot_corrections" ]; then
    echo " hot — $(echo "$hot_corrections" | tr '\n' ',' | sed 's/,$//')"
elif $use_db; then
    echo " hot"
else
    echo " total"
fi

echo -n "Staleness:    $stale_count memories"
if $use_db; then
    echo -n " past half-life"
else
    echo -n " older than 90 days"
fi
if [ "$stale_count" -gt 0 ] && [ "$stale_count" -le 5 ] && [ -n "$stale_list" ]; then
    echo ""
    echo "$stale_list" | while IFS= read -r line; do echo "              $line"; done
elif [ "$stale_count" -gt 5 ]; then
    echo " (showing 5)"
    if [ -n "$stale_list" ]; then
        echo "$stale_list" | while IFS= read -r line; do echo "              $line"; done
    fi
else
    echo ""
fi

echo -n "Provenance:   "
if [ -n "$prov" ]; then
    echo "$prov" | tr '\n' ' '
    echo ""
else
    echo "no data yet"
fi

# ACS line (already formatted with leading spaces by acs-check.sh)
echo "ACS:         $(echo "$acs_line" | sed 's/^[[:space:]]*acs:[[:space:]]*//')"
echo "Session:      $session_count sessions logged"
echo "Storage:      $storage_status"
echo ""

# ============================================================================
# ADJUSTMENTS — mechanical, bounded, tagged with set_point + provenance
# ============================================================================

adjustments=()

# Priority 1: critical coherence
if [ "$coherence" = "CRITICAL" ]; then
    adjustments+=("[set_point:pressure_warn, prov:human] Pressure critical (p=$pressure) — compress before adding new memories")
fi

# Priority 2: drift
if awk -v d="$drift" 'BEGIN { exit (d+0 >= 1.0) ? 0 : 1 }' 2>/dev/null; then
    adjustments+=("[set_point:drift_warn, prov:human] System review due (d=$drift) — run health diagnostics this session")
fi

# Priority 3: stale memories
if [ "$stale_count" -gt 0 ]; then
    adjustments+=("[set_point:staleness_threshold, prov:human] $stale_count stale memories — verify before citing as current fact")
fi

# Priority 4: hot corrections
if [ "$hot_count" -gt 0 ] && $use_db && [ -n "$hot_corrections" ]; then
    top_correction=$(echo "$hot_corrections" | head -1)
    adjustments+=("[set_point:correction_heat, prov:human] Hot correction: $top_correction — watch for this pattern")
fi

# Priority 5: storage integrity
if [ "$storage_status" = "INTEGRITY FAILURE" ]; then
    adjustments+=("[set_point:integrity_check, prov:environment] Storage integrity degraded — run rebuild-db.sh")
elif [ "$storage_status" = "NO DB" ] && [ "$db_enabled" = "true" ]; then
    adjustments+=("[set_point:integrity_check, prov:environment] Database not built — run rebuild-db.sh")
fi

# Priority 6: memory file drift (context-layer staleness detection)
# Compare checksums in MEMORY.md against actual files — catches post-compression divergence
drifted_files=""
drifted_count=0
if [ -f "$TRELLIS/memory/MEMORY.md" ]; then
    while IFS= read -r line; do
        file_path=$(echo "$line" | sed -n 's/.*`memory\/\([^`]*\)`.*/\1/p')
        stored_sha=$(echo "$line" | sed -n 's/.*\[sha:\([a-f0-9]*\)\].*/\1/p')
        [ -z "$file_path" ] || [ -z "$stored_sha" ] && continue
        full_path="$TRELLIS/memory/$file_path"
        [ -f "$full_path" ] || continue
        actual_sha=$(sha256sum "$full_path" | cut -c1-8)
        if [ "$actual_sha" != "$stored_sha" ]; then
            drifted_files="${drifted_files}${file_path} "
            drifted_count=$((drifted_count + 1))
        fi
    done < "$TRELLIS/memory/MEMORY.md"
fi
if [ "$drifted_count" -gt 0 ]; then
    adjustments+=("[set_point:checksum_drift, prov:environment] $drifted_count file(s) changed since MEMORY.md checksums: ${drifted_files}— re-read before citing")
fi

echo "ADJUSTMENTS:"
if [ ${#adjustments[@]} -eq 0 ]; then
    echo "  None — system nominal"
else
    # Cap at 3
    max=3
    for ((i=0; i<${#adjustments[@]} && i<max; i++)); do
        echo "  - ${adjustments[$i]}"
    done
fi
