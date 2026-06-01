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

config="$TRELLIS/config.yaml"

# Read threshold from config
threshold=$(grep -E '^\s*threshold:' "$config" 2>/dev/null | head -1 | sed 's/.*threshold:[[:space:]]*//; s/[[:space:]]*#.*//' | tr -d '\r')
threshold="${threshold:-3}"

# Read active plugins from config
# Parses the YAML list under plugins.active
in_active=false
plugins=()
while IFS= read -r line; do
    if echo "$line" | grep -qE '^\s*active:'; then
        in_active=true
        continue
    fi
    if $in_active; then
        if echo "$line" | grep -qE '^\s*-\s'; then
            plugin=$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*//' | tr -d '\r')
            plugins+=("$plugin")
        else
            break
        fi
    fi
done < "$config"

echo "Trellis Topology"
echo "================"
echo "Memory:      ACTIVE (built-in)"

axes=1
inactive=()
unassembled=()

for plugin in "${plugins[@]}"; do
    plugin_dir="$TRELLIS/plugins/$plugin"
    manifest="$plugin_dir/plugin.yaml"

    if [ ! -d "$plugin_dir" ]; then
        echo "$plugin:  ERROR (directory missing)"
        inactive+=("$plugin")
        continue
    fi

    if [ ! -f "$manifest" ]; then
        echo "$plugin:  ERROR (plugin.yaml missing)"
        inactive+=("$plugin")
        continue
    fi

    axis=$(grep -E '^\s*axis:' "$manifest" 2>/dev/null | head -1 | sed 's/.*axis:[[:space:]]*//' | tr -d '\r')

    # Verify plugin directives are actually assembled into directives.md
    section_header=$(grep -E '^\s*directives_section:' "$manifest" 2>/dev/null | head -1 | sed 's/.*directives_section:[[:space:]]*//; s/^"//; s/"$//' | tr -d '\r')
    assembled="yes"
    if [ -n "$section_header" ] && [ -f "$TRELLIS/directives.md" ]; then
        next_line=$(awk -v header="$section_header" '$0 == header { getline; print; exit }' "$TRELLIS/directives.md")
        if echo "$next_line" | grep -q '^(populated when'; then
            assembled="no"
        fi
    fi

    if [ "$assembled" = "yes" ]; then
        echo "$plugin: ACTIVE ($axis, assembled)"
    else
        echo "$plugin: ACTIVE ($axis, NOT ASSEMBLED) [WARN]"
        unassembled+=("$plugin")
    fi
    axes=$((axes + 1))
done

echo ""

if [ "$axes" -ge "$threshold" ]; then
    echo "Axes: $axes/$threshold [FULL]"
else
    echo "Axes: $axes/$threshold [BELOW THRESHOLD]"
    echo "Warning: Sub-threshold governance increases drift risk."
    if [ "${#inactive[@]}" -gt 0 ]; then
        echo "Inactive: ${inactive[*]}"
    fi
    exit 1
fi

if [ "${#unassembled[@]}" -gt 0 ]; then
    echo "Warning: ${#unassembled[@]} plugin(s) configured but not assembled into directives.md"
    echo "Run: scripts/assemble-directives.sh --write"
fi
