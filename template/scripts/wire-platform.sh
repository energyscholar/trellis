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

PLATFORM="${1:-auto}"

# Auto-detect platform
if [ "$PLATFORM" = "auto" ]; then
    if [ -f "$HOME/.claude/CLAUDE.md" ] || command -v claude &>/dev/null; then
        PLATFORM="claude-code"
    elif [ -d "$HOME/.cursor" ]; then
        PLATFORM="cursor"
    else
        PLATFORM="claude-code"
    fi
    echo "Auto-detected platform: $PLATFORM" >&2
fi

generate_block() {
    local install_path="$TRELLIS"
    case "$PLATFORM" in
        claude-code)
            cat <<BLOCK
<!-- TRELLIS START -- do not edit this block manually -->
## Trellis Governance

Full directives: read the file at ${install_path}/directives.md at session start.

**Minimum session loop:**
- **Start:** Read \`${install_path}/memory/MEMORY.md\`, then \`${install_path}/memory/corrections.md\`
- **End:** Update \`${install_path}/memory/MEMORY.md\`, run \`${install_path}/scripts/memory-sync.sh\`
<!-- TRELLIS END -->
BLOCK
            ;;
        codex)
            cat <<BLOCK
<!-- TRELLIS START -- do not edit this block manually -->
## Trellis Governance

Full directives: read the file at ${install_path}/directives.md at session start.

**Minimum session loop:**
- **Start:** Read \`${install_path}/memory/MEMORY.md\`, then \`${install_path}/memory/corrections.md\`
- **End:** Update \`${install_path}/memory/MEMORY.md\`, run \`${install_path}/scripts/memory-sync.sh\`
<!-- TRELLIS END -->
BLOCK
            ;;
        cursor)
            cat <<BLOCK
---
description: Trellis governance system
alwaysApply: true
---
# Trellis Governance
Full directives: read the file at ${install_path}/directives.md at session start.
Start: Read ${install_path}/memory/MEMORY.md, then corrections.md
End: Update MEMORY.md, run ${install_path}/scripts/memory-sync.sh
BLOCK
            ;;
        *)
            echo "Unknown platform: $PLATFORM" >&2
            echo "Supported: claude-code, codex, cursor" >&2
            exit 1
            ;;
    esac
}

target_file() {
    case "$PLATFORM" in
        claude-code) echo "$HOME/.claude/CLAUDE.md" ;;
        codex) echo "AGENTS.md" ;;
        cursor) echo "$HOME/.cursor/rules/trellis.mdc" ;;
    esac
}

# Generate and output the block
echo "Platform: $PLATFORM" >&2
echo "Target: $(target_file)" >&2
echo "Install path: $TRELLIS" >&2
echo "" >&2

generate_block
