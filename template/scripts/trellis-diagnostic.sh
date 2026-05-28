#!/usr/bin/env bash
set -euo pipefail

resolve_trellis_home() {
    if [ -n "${TRELLIS_HOME:-}" ]; then echo "$TRELLIS_HOME"
    elif [ -f "$HOME/.config/trellis/home" ]; then cat "$HOME/.config/trellis/home"
    else echo "$HOME/.trellis"; fi
}
TRELLIS="$(resolve_trellis_home)"
[ -d "$TRELLIS" ] || { echo "Trellis not found at $TRELLIS" >&2; exit 0; }

config="$TRELLIS/config.yaml"
get_config() { local v; v=$(grep -E "^\s*${1}:" "$config" 2>/dev/null | head -1 | sed "s/.*${1}:[[:space:]]*//; s/[[:space:]]*#.*//" | tr -d '\r') || true; echo "${v:-$2}"; }
issues=()
version=$(get_config "version" "unknown")
platform=$(get_config "type" "unknown")
tier=$(get_config "tier" "unknown")
memory_cap=$(get_config "memory_index_cap" "200")
comp_trigger=$(get_config "compression_trigger" "180")

echo "=== TRELLIS DIAGNOSTIC REPORT ==="
echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "Version: $version"
echo "Platform: $platform"
echo "Storage tier: $tier"
echo ""
echo "--- Memory ---"

sessions=0
if [ -f "$TRELLIS/memory/session-log.md" ]; then
    sessions=$(grep -cE '^\|[^-]' "$TRELLIS/memory/session-log.md" 2>/dev/null || echo 0)
    sessions=$((sessions > 1 ? sessions - 1 : 0))
fi
echo "Sessions logged: $sessions"

if [ -f "$TRELLIS/memory/training-primer.md" ]; then
    tp_done=$(grep -c '\- \[x\]' "$TRELLIS/memory/training-primer.md" 2>/dev/null || echo 0)
    tp_total=$(grep -c '\- \[' "$TRELLIS/memory/training-primer.md" 2>/dev/null || echo 0)
    echo "Training primer: ${tp_done}/${tp_total} complete"
else
    echo "Training primer: archived"
fi

corrections=0
[ -f "$TRELLIS/memory/corrections.md" ] && \
    corrections=$(grep -cE '^### Correction #' "$TRELLIS/memory/corrections.md" 2>/dev/null || echo 0)
echo "Corrections: $corrections"
echo "Memory files: $(find "$TRELLIS/memory" -name '*.md' 2>/dev/null | wc -l)"

mem_lines=0
[ -f "$TRELLIS/memory/MEMORY.md" ] && mem_lines=$(wc -l < "$TRELLIS/memory/MEMORY.md")
echo "MEMORY.md lines: $mem_lines / $memory_cap"
if [ "$mem_lines" -ge "$comp_trigger" ] 2>/dev/null; then
    issues+=("MEMORY.md at $mem_lines lines (compression trigger: $comp_trigger)")
fi

echo ""
echo "--- Health ---"
if [ -x "$TRELLIS/scripts/health-check.sh" ]; then
    health_out=$(bash "$TRELLIS/scripts/health-check.sh" 2>&1 || true)
    echo "$health_out"
    echo "$health_out" | grep -qi 'warn' && issues+=("health-check.sh reported warnings")
else
    echo "health-check.sh not found"
fi

echo ""
echo "--- Topology ---"
if [ -x "$TRELLIS/scripts/topology-check.sh" ]; then
    topo_out=$(bash "$TRELLIS/scripts/topology-check.sh" 2>&1 || true)
    echo "$topo_out"
    echo "$topo_out" | grep -qi 'below threshold' && issues+=("Topology below threshold")
else
    echo "topology-check.sh not found"
fi

echo ""
echo "--- Inventory ---"
script_total=0; script_exec=0
for s in "$TRELLIS"/scripts/*.sh; do
    [ -f "$s" ] || continue
    script_total=$((script_total + 1))
    [ -x "$s" ] && script_exec=$((script_exec + 1))
done
echo "Scripts: $script_total ($script_exec executable)"
[ "$script_exec" -lt "$script_total" ] && \
    issues+=("$((script_total - script_exec)) script(s) not executable")

plugin_list=$(find "$TRELLIS/plugins" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | xargs -r -n1 basename | sort | tr '\n' ' ') || true
echo "Plugins: ${plugin_list:-none}"

profile_list=$(find "$TRELLIS/profiles" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | xargs -r -n1 basename | sort | tr '\n' ' ') || true
profile_count=$(echo "$profile_list" | wc -w)
echo "Profiles: $profile_count (${profile_list:-none})"

for expected in config.yaml memory/MEMORY.md memory/corrections.md memory/session-log.md directives.md; do
    [ -f "$TRELLIS/$expected" ] || issues+=("$expected missing")
done

echo ""
echo "--- Issues ---"
if [ ${#issues[@]} -eq 0 ]; then
    echo "None detected."
else
    printf -- '- %s\n' "${issues[@]}"
fi

echo ""
echo "--- Privacy ---"
echo "This report contains structural metadata only."
echo "No memory content, correction text, personal data, or identity details are included."
echo "You control what you share — review before sending."
echo ""
echo "=== END DIAGNOSTIC ==="
echo ""
cat <<'FEEDBACK'
--- YOUR FEEDBACK (optional, fill in below) ---
What went well:

What was confusing:

What broke:

Feature requests:

Other:
FEEDBACK
