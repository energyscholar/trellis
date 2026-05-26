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
    echo "$plugin: ACTIVE ($axis)"
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
