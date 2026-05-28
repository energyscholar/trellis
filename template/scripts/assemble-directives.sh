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

# Read from unassembled base template; write to assembled directives
if [ -f "$TRELLIS/directives-base.md" ]; then
    read_from="$TRELLIS/directives-base.md"
else
    read_from="$TRELLIS/directives.md"
fi
write_to="$TRELLIS/directives.md"

if [ ! -f "$read_from" ]; then
    echo "Base directives not found at $read_from" >&2
    exit 1
fi

# Read active plugins from config
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

# Start with base directives
output=$(cat "$read_from")

# For each active plugin, replace its section placeholder with actual content
for plugin in "${plugins[@]}"; do
    plugin_dir="$TRELLIS/plugins/$plugin"
    manifest="$plugin_dir/plugin.yaml"

    if [ ! -f "$manifest" ]; then
        echo "Warning: plugin $plugin has no manifest, skipping" >&2
        continue
    fi

    # Read the section header from plugin manifest
    section_header=$(grep -E '^\s*directives_section:' "$manifest" 2>/dev/null | head -1 | sed 's/.*directives_section:[[:space:]]*//; s/^"//; s/"$//' | tr -d '\r')

    if [ -z "$section_header" ]; then
        echo "Warning: plugin $plugin has no directives_section, skipping" >&2
        continue
    fi

    # Read directives fragment file
    directives_file=$(grep -E '^\s*directives:' "$manifest" 2>/dev/null | head -1 | sed 's/.*directives:[[:space:]]*//' | tr -d '\r')
    directives_path="$plugin_dir/$directives_file"

    if [ ! -f "$directives_path" ]; then
        echo "Warning: plugin $plugin directives file not found at $directives_path, skipping" >&2
        continue
    fi

    fragment=$(cat "$directives_path")

    # Replace the section header + placeholder line with section header + fragment
    # The placeholder pattern is: ## Section Header\n(populated when...)
    section_escaped=$(echo "$section_header" | sed 's/[#]/\\#/g')
    output=$(echo "$output" | awk -v header="$section_header" -v content="$fragment" '
        $0 == header {
            print header
            print content
            getline
            if ($0 ~ /^\(populated when/) next
            else print
            next
        }
        {print}
    ')
done

# Write or print
if [ "${1:-}" = "--write" ]; then
    echo "$output" > "$write_to"
    echo "Directives assembled: $write_to"
else
    echo "$output"
fi
