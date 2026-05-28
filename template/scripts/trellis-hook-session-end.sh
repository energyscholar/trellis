#!/usr/bin/env bash
# Trellis SessionEnd hook for Claude Code settings.json
# Syncs memory and auto-saves the active profile.
#
# Wire into settings.json:
#   "SessionEnd": [{ "hooks": [{ "type": "command",
#     "command": "~/.trellis/scripts/trellis-hook-session-end.sh",
#     "timeout": 15 }] }]

set -euo pipefail

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
[ -d "$TRELLIS" ] || exit 0

# Memory sync (local commit)
if [ -x "$TRELLIS/scripts/memory-sync.sh" ]; then
    bash "$TRELLIS/scripts/memory-sync.sh" 2>/dev/null || true
fi

# Auto-save active profile
config="$TRELLIS/config.yaml"
active=$(grep -E '^\s*active_profile:' "$config" 2>/dev/null | sed 's/.*active_profile:[[:space:]]*//; s/[[:space:]]*#.*//' | tr -d '\r"'"'" || echo "")

if [ -n "$active" ] && [ "$active" != "(unsaved)" ] && [ -x "$TRELLIS/scripts/trellis-profile.sh" ]; then
    bash "$TRELLIS/scripts/trellis-profile.sh" save "$active" 2>/dev/null || true
fi
