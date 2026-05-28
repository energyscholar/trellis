#!/usr/bin/env bash
set -euo pipefail

# Trellis profile checkpoint utility
# Run from your terminal (not the AI session) to save/export/import memory states.
#
# Usage:
#   checkpoint.sh save <name> [description]    Save + pin + export
#   checkpoint.sh load <name>                  Import + load
#   checkpoint.sh nuke                         Wipe install, keep exports
#   checkpoint.sh reinstall                    Nuke + fresh install from template
#   checkpoint.sh list                         Show saved profiles

REPO="$(cd "$(dirname "$0")" && pwd)"
EXPORT_DIR="$REPO/checkpoints"
mkdir -p "$EXPORT_DIR"

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
PROFILE="$TRELLIS/scripts/trellis-profile.sh"

cmd_save() {
    local name="$1"
    local desc="${2:-Checkpoint $name}"

    if [ ! -d "$TRELLIS" ]; then
        echo "No Trellis install found at $TRELLIS" >&2; exit 1
    fi

    bash "$PROFILE" save "$name" -d "$desc"
    bash "$PROFILE" pin "$name"
    bash "$PROFILE" export "$name" "$EXPORT_DIR/${name}.trellis-profile.tar.gz"

    echo ""
    echo "Checkpoint saved, pinned, and exported to:"
    echo "  $EXPORT_DIR/${name}.trellis-profile.tar.gz"
}

cmd_load() {
    local name="$1"
    local archive="$EXPORT_DIR/${name}.trellis-profile.tar.gz"

    if [ ! -d "$TRELLIS" ]; then
        echo "No Trellis install found at $TRELLIS" >&2; exit 1
    fi

    if [ ! -f "$archive" ]; then
        echo "No checkpoint found: $archive" >&2
        echo "Available:" >&2
        ls "$EXPORT_DIR"/*.trellis-profile.tar.gz 2>/dev/null | sed 's|.*/||; s|\.trellis-profile\.tar\.gz||' | sed 's/^/  /' >&2
        exit 1
    fi

    # Import if not already a profile
    if [ ! -d "$TRELLIS/profiles/$name" ]; then
        bash "$PROFILE" import "$archive" "$name"
    fi

    bash "$PROFILE" load "$name"
}

cmd_nuke() {
    if [ ! -d "$TRELLIS" ]; then
        echo "Nothing to nuke — $TRELLIS doesn't exist"
        exit 0
    fi

    rm -rf "$TRELLIS"
    rm -f "$HOME/.config/trellis/home"
    echo "Nuked: $TRELLIS"
    echo "Breadcrumb removed."
    echo "Checkpoints preserved at: $EXPORT_DIR/"
    ls "$EXPORT_DIR"/*.trellis-profile.tar.gz 2>/dev/null | sed 's/^/  /' || echo "  (none)"
}

cmd_reinstall() {
    cmd_nuke

    cp -r "$REPO/template/" "$TRELLIS/"
    chmod +x "$TRELLIS/scripts/"*.sh

    cd "$TRELLIS"
    git init -q
    git config user.name "Trellis"
    git config user.email "trellis@local"
    git add -A
    git commit -q -m "Trellis initial install"

    mkdir -p "$HOME/.config/trellis"
    echo "$TRELLIS" > "$HOME/.config/trellis/home"

    echo ""
    echo "Fresh install at $TRELLIS"
    echo "Identity fields empty — next AI session will ask."
    echo "Directives not assembled — next AI session or: $TRELLIS/scripts/assemble-directives.sh --write"
}

cmd_list() {
    echo "Exported checkpoints ($EXPORT_DIR):"
    for f in "$EXPORT_DIR"/*.trellis-profile.tar.gz; do
        [ -f "$f" ] || { echo "  (none)"; break; }
        local name size
        name=$(basename "$f" .trellis-profile.tar.gz)
        size=$(du -h "$f" | cut -f1)
        echo "  $name  ($size)"
    done

    echo ""
    if [ -d "$TRELLIS" ] && [ -x "$PROFILE" ]; then
        echo "Live profiles:"
        bash "$PROFILE" list
    else
        echo "No live Trellis install."
    fi
}

case "${1:-}" in
    save)      shift; cmd_save "$@" ;;
    load)      shift; cmd_load "$@" ;;
    nuke)      cmd_nuke ;;
    reinstall) cmd_reinstall ;;
    list)      cmd_list ;;
    *)
        echo "Usage: checkpoint.sh <command>"
        echo ""
        echo "  save <name> [desc]   Save + pin + export current memory state"
        echo "  load <name>          Import + load a checkpoint"
        echo "  nuke                 Wipe install, keep exported checkpoints"
        echo "  reinstall            Nuke + fresh install from template"
        echo "  list                 Show checkpoints and live profiles"
        ;;
esac
