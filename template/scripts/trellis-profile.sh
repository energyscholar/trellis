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

PROFILES_DIR="$TRELLIS/profiles"
mkdir -p "$PROFILES_DIR"

usage() {
    cat <<'USAGE'
trellis-profile.sh — Memory profile management

Commands:
  list                         Show all profiles with description + ACS state
  save <name> [-d "desc"]      Snapshot current memory state as a named profile
  load <name>                  Switch to a named profile (auto-saves current first)
  delete <name>                Remove a profile
  current                      Show active profile name
  (no args)                    Interactive menu

Profiles store: memory/, config.yaml, profile.yaml manifest.
Infrastructure (scripts/, plugins/) is shared — not per-profile.
USAGE
}

# --- Helpers ---

get_current_profile() {
    local config="$TRELLIS/config.yaml"
    grep -E '^\s*active_profile:' "$config" 2>/dev/null | sed 's/.*active_profile:[[:space:]]*//; s/[[:space:]]*#.*//' | tr -d '\r"'"'" || echo "(unsaved)"
}

set_current_profile() {
    local name="$1"
    local config="$TRELLIS/config.yaml"
    if grep -qE '^\s*active_profile:' "$config" 2>/dev/null; then
        sed -i "s|^\(\s*active_profile:\).*|\1 \"$name\"|" "$config"
    else
        # Add after the platform section
        if grep -q '^platform:' "$config"; then
            sed -i "/^platform:/a\\  active_profile: \"$name\"" "$config"
        else
            echo "  active_profile: \"$name\"" >> "$config"
        fi
    fi
}

get_acs_oneliner() {
    local dir="$1"
    local log="$dir/memory/session-log.md"
    if [ -f "$log" ]; then
        local count
        count=$(awk -F'|' '/^\| S[0-9]/ { n++ } END { print n+0 }' "$log")
        echo "$count sessions"
    else
        echo "0 sessions"
    fi
}

# --- Commands ---

cmd_list() {
    local current
    current=$(get_current_profile)

    echo "Trellis Memory Profiles"
    echo "======================="
    echo ""

    local i=0
    for pdir in "$PROFILES_DIR"/*/; do
        [ -d "$pdir" ] || continue
        local name desc sessions marker
        name=$(basename "$pdir")
        [ "$name" = "_autosave" ] && continue

        i=$((i + 1))
        desc=""
        if [ -f "$pdir/profile.yaml" ]; then
            desc=$(grep '^description:' "$pdir/profile.yaml" 2>/dev/null | sed 's/^description:[[:space:]]*//' | tr -d '"'"'")
        fi
        sessions=$(get_acs_oneliner "$pdir")

        marker=" "
        if [ "$name" = "$current" ]; then
            marker="*"
        fi

        printf "  %s %d. %-20s %s  (%s)\n" "$marker" "$i" "$name" "${desc:-(no description)}" "$sessions"
    done

    if [ "$i" -eq 0 ]; then
        echo "  (no profiles saved yet)"
        echo ""
        echo "  Save current state:  trellis-profile.sh save <name> -d \"description\""
    fi
    echo ""
    echo "  Active: $current"
}

cmd_save() {
    local name="$1"
    shift
    local desc=""

    while [ $# -gt 0 ]; do
        case "$1" in
            -d|--description) desc="$2"; shift 2 ;;
            *) desc="$1"; shift ;;
        esac
    done

    local target="$PROFILES_DIR/$name"
    mkdir -p "$target"

    # Copy memory state
    rm -rf "$target/memory"
    cp -r "$TRELLIS/memory" "$target/memory"
    cp "$TRELLIS/config.yaml" "$target/config.yaml"

    # Compute session count from the snapshot
    local sessions
    sessions=$(get_acs_oneliner "$target")

    # Write manifest
    cat > "$target/profile.yaml" <<MANIFEST
name: "$name"
description: "$desc"
created: $(date -u +%Y-%m-%dT%H:%M:%SZ)
sessions: $sessions
MANIFEST

    set_current_profile "$name"

    # Commit if git available
    if command -v git &>/dev/null && git -C "$TRELLIS" rev-parse --git-dir &>/dev/null; then
        git -C "$TRELLIS" add -A
        git -C "$TRELLIS" commit -m "Profile saved: $name" 2>/dev/null || true
    fi

    echo "Saved: $name ($sessions)"
    [ -n "$desc" ] && echo "  $desc"
}

cmd_load() {
    local name="$1"
    local target="$PROFILES_DIR/$name"

    if [ ! -d "$target" ]; then
        echo "Profile not found: $name" >&2
        echo "Available:" >&2
        for pdir in "$PROFILES_DIR"/*/; do
            [ -d "$pdir" ] || continue
            local n
            n=$(basename "$pdir")
            [ "$n" = "_autosave" ] && continue
            echo "  $n" >&2
        done
        exit 1
    fi

    # Auto-save current state
    local autosave="$PROFILES_DIR/_autosave"
    mkdir -p "$autosave"
    rm -rf "$autosave/memory"
    cp -r "$TRELLIS/memory" "$autosave/memory"
    cp "$TRELLIS/config.yaml" "$autosave/config.yaml"
    cat > "$autosave/profile.yaml" <<MANIFEST
name: "_autosave"
description: "Auto-saved before switching to $name"
created: $(date -u +%Y-%m-%dT%H:%M:%SZ)
sessions: $(get_acs_oneliner "$autosave")
MANIFEST

    # Load target profile
    rm -rf "$TRELLIS/memory"
    cp -r "$target/memory" "$TRELLIS/memory"
    cp "$target/config.yaml" "$TRELLIS/config.yaml"

    set_current_profile "$name"

    # Reassemble directives
    if [ -x "$TRELLIS/scripts/assemble-directives.sh" ]; then
        bash "$TRELLIS/scripts/assemble-directives.sh" --write 2>/dev/null || true
    fi

    # Commit if git available
    if command -v git &>/dev/null && git -C "$TRELLIS" rev-parse --git-dir &>/dev/null; then
        git -C "$TRELLIS" add -A
        git -C "$TRELLIS" commit -m "Profile loaded: $name" 2>/dev/null || true
    fi

    local sessions
    sessions=$(get_acs_oneliner "$TRELLIS")
    echo "Loaded: $name ($sessions)"
    if [ -f "$target/profile.yaml" ]; then
        local desc
        desc=$(grep '^description:' "$target/profile.yaml" 2>/dev/null | sed 's/^description:[[:space:]]*//' | tr -d '"'"'")
        [ -n "$desc" ] && echo "  $desc"
    fi
    echo ""
    echo "Previous state auto-saved to _autosave."
    echo "Re-read memory/MEMORY.md and memory/corrections.md to activate."
}

cmd_delete() {
    local name="$1"

    if [ "$name" = "_autosave" ]; then
        echo "Cannot delete _autosave (safety net)" >&2
        exit 1
    fi

    local target="$PROFILES_DIR/$name"
    if [ ! -d "$target" ]; then
        echo "Profile not found: $name" >&2
        exit 1
    fi

    local current
    current=$(get_current_profile)
    if [ "$name" = "$current" ]; then
        echo "Cannot delete the active profile. Switch first." >&2
        exit 1
    fi

    rm -rf "$target"

    if command -v git &>/dev/null && git -C "$TRELLIS" rev-parse --git-dir &>/dev/null; then
        git -C "$TRELLIS" add -A
        git -C "$TRELLIS" commit -m "Profile deleted: $name" 2>/dev/null || true
    fi

    echo "Deleted: $name"
}

cmd_current() {
    get_current_profile
}

cmd_interactive() {
    echo "Trellis Memory Profiles"
    echo "======================="
    echo ""

    local names=()
    local i=0
    for pdir in "$PROFILES_DIR"/*/; do
        [ -d "$pdir" ] || continue
        local name
        name=$(basename "$pdir")
        [ "$name" = "_autosave" ] && continue
        names+=("$name")

        i=$((i + 1))
        local desc=""
        if [ -f "$pdir/profile.yaml" ]; then
            desc=$(grep '^description:' "$pdir/profile.yaml" 2>/dev/null | sed 's/^description:[[:space:]]*//' | tr -d '"'"'")
        fi
        local sessions
        sessions=$(get_acs_oneliner "$pdir")
        local current marker
        current=$(get_current_profile)
        marker=" "
        [ "$name" = "$current" ] && marker="*"
        printf "  %s %d. %-20s %s  (%s)\n" "$marker" "$i" "$name" "${desc:-(no description)}" "$sessions"
    done

    if [ "$i" -eq 0 ]; then
        echo "  (no profiles saved yet)"
        echo ""
        echo "  Save current state:  trellis-profile.sh save <name> -d \"description\""
        exit 0
    fi

    echo ""
    printf "Select profile (1-%d), or 'q' to quit: " "$i"
    read -r choice

    if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
        exit 0
    fi

    if [ "$choice" -ge 1 ] 2>/dev/null && [ "$choice" -le "$i" ] 2>/dev/null; then
        local idx=$((choice - 1))
        local selected="${names[$idx]}"
        echo ""
        cmd_load "$selected"
    else
        echo "Invalid selection." >&2
        exit 1
    fi
}

# --- Dispatch ---

case "${1:-}" in
    list)    cmd_list ;;
    save)    shift; cmd_save "$@" ;;
    load)    shift; cmd_load "$@" ;;
    delete)  shift; cmd_delete "$@" ;;
    current) cmd_current ;;
    -h|--help|help) usage ;;
    "")      cmd_interactive ;;
    *)       echo "Unknown command: $1" >&2; usage; exit 1 ;;
esac
