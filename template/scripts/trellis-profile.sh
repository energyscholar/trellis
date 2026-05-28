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
  pin <name>                   Protect profile from auto-save overwrites
  unpin <name>                 Remove pin protection
  export <name> [path]         Export profile as .tar.gz (default: ./<name>.trellis-profile.tar.gz)
  import <path> [name]         Import profile from .tar.gz or directory
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

get_session_count() {
    local dir="$1"
    local log="$dir/memory/session-log.md"
    if [ -f "$log" ]; then
        awk -F'|' '/^\| S[0-9]/ { n++ } END { print n+0 }' "$log"
    else
        echo "0"
    fi
}

get_acs_oneliner() {
    local dir="$1"
    local count
    count=$(get_session_count "$dir")
    if [ "$count" -eq 0 ]; then
        echo "$count|  --|  --|--|DORMANT"
        return
    fi
    local acs_line
    acs_line=$(ACS_MIN_SESSIONS=0 TRELLIS_HOME="$dir" bash "$TRELLIS/scripts/acs-check.sh" --oneliner 2>/dev/null) || true
    if echo "$acs_line" | grep -q 'λ='; then
        local lambda gap weak status
        lambda=$(echo "$acs_line" | sed 's/.*λ=\([0-9.]*\).*/\1/')
        gap=$(echo "$acs_line" | sed 's/.*gap=\([0-9.]*\).*/\1/')
        weak=$(echo "$acs_line" | sed 's/.*weak=\([^[:space:]]*\).*/\1/')
        status=$(echo "$acs_line" | sed 's/.*\[\([^]]*\)\].*/\1/')
        echo "$count|$lambda|$gap|$weak|$status"
    else
        echo "$count|  --|  --|--|--"
    fi
}

validate_name() {
    local name="$1"
    if [ -z "$name" ]; then
        echo "Profile name cannot be empty" >&2; exit 1
    fi
    if echo "$name" | grep -qE '/|\.\.'; then
        echo "Invalid profile name: $name" >&2; exit 1
    fi
    if echo "$name" | grep -qE '^\.*$'; then
        echo "Invalid profile name: $name" >&2; exit 1
    fi
    if [ "$name" = "_autosave" ]; then
        echo "Profile name '_autosave' is reserved" >&2; exit 1
    fi
}

is_pinned() {
    local name="$1"
    local manifest="$PROFILES_DIR/$name/profile.yaml"
    [ -f "$manifest" ] && grep -q '^pinned: true' "$manifest" 2>/dev/null
}

# --- Commands ---

cmd_list() {
    local current
    current=$(get_current_profile)

    echo "Trellis Memory Profiles"
    echo "======================="
    echo ""
    printf "       %-16s  %4s  %5s  %5s  %-13s %-14s  %s\n" \
        "Name" "Sess" "λ₁" "Gap" "Weakest" "Status" ""
    printf "       %-16s  %4s  %5s  %5s  %-13s %-14s  %s\n" \
        "----------------" "----" "-----" "-----" "-------------" "--------------" ""

    local i=0
    for pdir in "$PROFILES_DIR"/*/; do
        [ -d "$pdir" ] || continue
        local name desc acs_data marker pin_marker
        name=$(basename "$pdir")
        [ "$name" = "_autosave" ] && continue

        i=$((i + 1))
        desc=""
        if [ -f "$pdir/profile.yaml" ]; then
            desc=$(grep '^description:' "$pdir/profile.yaml" 2>/dev/null | sed 's/^description:[[:space:]]*//' | tr -d '"'"'")
        fi

        acs_data=$(get_acs_oneliner "$pdir")
        local sessions lambda gap weak status
        sessions=$(echo "$acs_data" | cut -d'|' -f1)
        lambda=$(echo "$acs_data" | cut -d'|' -f2)
        gap=$(echo "$acs_data" | cut -d'|' -f3)
        weak=$(echo "$acs_data" | cut -d'|' -f4)
        status=$(echo "$acs_data" | cut -d'|' -f5)

        marker=" "
        [ "$name" = "$current" ] && marker="*"

        pin_marker=""
        is_pinned "$name" && pin_marker="[pinned]"

        printf "  %s %d. %-16s  %4s  %5s  %5s  %-13s %-14s  %s\n" \
            "$marker" "$i" "$name" "$sessions" "$lambda" "$gap" "$weak" "$status" "$pin_marker"
        [ -n "$desc" ] && printf "       %-16s  %s\n" "" "$desc"
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
    validate_name "$name"
    if is_pinned "$name"; then
        echo "Profile '$name' is pinned. Unpin first or save to a different name." >&2
        exit 1
    fi
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
    sessions=$(get_session_count "$target")

    # Write manifest
    cat > "$target/profile.yaml" <<MANIFEST
name: "$name"
description: "$desc"
created: $(date -u +%Y-%m-%dT%H:%M:%SZ)
sessions: $sessions sessions
MANIFEST

    set_current_profile "$name"

    # Commit if git available
    if command -v git &>/dev/null && git -C "$TRELLIS" rev-parse --git-dir &>/dev/null; then
        git -C "$TRELLIS" add -A
        git -C "$TRELLIS" commit -m "Profile saved: $name" 2>/dev/null || true
    fi

    echo "Saved: $name ($sessions sessions)"
    [ -n "$desc" ] && echo "  $desc"
}

cmd_load() {
    local name="$1"
    validate_name "$name"
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
sessions: $(get_session_count "$autosave") sessions
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
    sessions=$(get_session_count "$TRELLIS")
    echo "Loaded: $name ($sessions sessions)"
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
    validate_name "$name"

    if is_pinned "$name"; then
        echo "Profile '$name' is pinned. Unpin first." >&2
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
    printf "       %-16s  %4s  %5s  %5s  %-13s %-14s  %s\n" \
        "Name" "Sess" "λ₁" "Gap" "Weakest" "Status" ""
    printf "       %-16s  %4s  %5s  %5s  %-13s %-14s  %s\n" \
        "----------------" "----" "-----" "-----" "-------------" "--------------" ""

    local names=()
    local i=0
    local current
    current=$(get_current_profile)
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

        local acs_data sessions lambda gap weak status
        acs_data=$(get_acs_oneliner "$pdir")
        sessions=$(echo "$acs_data" | cut -d'|' -f1)
        lambda=$(echo "$acs_data" | cut -d'|' -f2)
        gap=$(echo "$acs_data" | cut -d'|' -f3)
        weak=$(echo "$acs_data" | cut -d'|' -f4)
        status=$(echo "$acs_data" | cut -d'|' -f5)

        local marker=" "
        [ "$name" = "$current" ] && marker="*"
        local pin_marker=""
        is_pinned "$name" && pin_marker="[pinned]"

        printf "  %s %d. %-16s  %4s  %5s  %5s  %-13s %-14s  %s\n" \
            "$marker" "$i" "$name" "$sessions" "$lambda" "$gap" "$weak" "$status" "$pin_marker"
        [ -n "$desc" ] && printf "       %-16s  %s\n" "" "$desc"
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

cmd_pin() {
    local name="$1"
    validate_name "$name"
    if [ ! -d "$PROFILES_DIR/$name" ]; then
        echo "Profile not found: $name" >&2; exit 1
    fi
    local manifest="$PROFILES_DIR/$name/profile.yaml"
    if grep -q '^pinned:' "$manifest" 2>/dev/null; then
        sed -i 's/^pinned:.*/pinned: true/' "$manifest"
    else
        echo "pinned: true" >> "$manifest"
    fi
    if command -v git &>/dev/null && git -C "$TRELLIS" rev-parse --git-dir &>/dev/null; then
        git -C "$TRELLIS" add -A
        git -C "$TRELLIS" commit -m "Profile pinned: $name" 2>/dev/null || true
    fi
    echo "Pinned: $name (protected from auto-save)"
}

cmd_unpin() {
    local name="$1"
    validate_name "$name"
    if [ ! -d "$PROFILES_DIR/$name" ]; then
        echo "Profile not found: $name" >&2; exit 1
    fi
    local manifest="$PROFILES_DIR/$name/profile.yaml"
    sed -i '/^pinned:/d' "$manifest"
    if command -v git &>/dev/null && git -C "$TRELLIS" rev-parse --git-dir &>/dev/null; then
        git -C "$TRELLIS" add -A
        git -C "$TRELLIS" commit -m "Profile unpinned: $name" 2>/dev/null || true
    fi
    echo "Unpinned: $name"
}

cmd_export() {
    local name="$1"
    validate_name "$name"
    local dest="${2:-./${name}.trellis-profile.tar.gz}"
    local source="$PROFILES_DIR/$name"
    if [ ! -d "$source" ]; then
        echo "Profile not found: $name" >&2; exit 1
    fi
    tar czf "$dest" -C "$PROFILES_DIR" "$name"
    local size
    size=$(du -h "$dest" | cut -f1)
    echo "Exported: $name → $dest ($size)"
}

cmd_import() {
    local path="$1"
    local import_name="${2:-}"
    local _import_tmpdir=""
    local source=""

    if [[ "$path" == *.tar.gz || "$path" == *.tgz ]]; then
        _import_tmpdir=$(mktemp -d)
        tar xzf "$path" -C "$_import_tmpdir"
        for d in "$_import_tmpdir"/*/; do
            [ -d "$d/memory" ] && { source="$d"; break; }
        done
        if [ -z "$source" ]; then
            rm -rf "$_import_tmpdir"
            echo "Archive does not contain a valid profile (no memory/ directory)" >&2; exit 1
        fi
    elif [ -d "$path" ]; then
        source="$path"
    else
        echo "Path is not a tarball or directory: $path" >&2; exit 1
    fi

    if [ ! -d "$source/memory" ]; then
        [ -n "$_import_tmpdir" ] && rm -rf "$_import_tmpdir"
        echo "Invalid profile: missing memory/ directory" >&2; exit 1
    fi
    if [ ! -f "$source/config.yaml" ]; then
        [ -n "$_import_tmpdir" ] && rm -rf "$_import_tmpdir"
        echo "Invalid profile: missing config.yaml" >&2; exit 1
    fi

    # Determine name
    local name="$import_name"
    if [ -z "$name" ] && [ -f "$source/profile.yaml" ]; then
        name=$(grep '^name:' "$source/profile.yaml" 2>/dev/null | sed 's/^name:[[:space:]]*//' | tr -d '"'"'")
    fi
    if [ -z "$name" ]; then
        name=$(basename "$path")
        name="${name%.trellis-profile.tar.gz}"
        name="${name%.tar.gz}"
        name="${name%.tgz}"
    fi

    validate_name "$name"

    if [ -d "$PROFILES_DIR/$name" ]; then
        [ -n "$_import_tmpdir" ] && rm -rf "$_import_tmpdir"
        echo "Profile '$name' already exists. Delete it first." >&2; exit 1
    fi

    local target="$PROFILES_DIR/$name"
    mkdir -p "$target"
    cp -r "$source/memory" "$target/memory"
    cp "$source/config.yaml" "$target/config.yaml"
    if [ -f "$source/profile.yaml" ]; then
        cp "$source/profile.yaml" "$target/profile.yaml"
        sed -i "s|^name:.*|name: \"$name\"|" "$target/profile.yaml"
    else
        cat > "$target/profile.yaml" <<MANIFEST
name: "$name"
description: ""
created: $(date -u +%Y-%m-%dT%H:%M:%SZ)
MANIFEST
    fi

    [ -n "$_import_tmpdir" ] && rm -rf "$_import_tmpdir"

    if command -v git &>/dev/null && git -C "$TRELLIS" rev-parse --git-dir &>/dev/null; then
        git -C "$TRELLIS" add -A
        git -C "$TRELLIS" commit -m "Profile imported: $name" 2>/dev/null || true
    fi

    echo "Imported: $name"
}

# --- Dispatch ---

case "${1:-}" in
    list)    cmd_list ;;
    save)    shift; cmd_save "$@" ;;
    load)    shift; cmd_load "$@" ;;
    delete)  shift; cmd_delete "$@" ;;
    pin)     shift; cmd_pin "$@" ;;
    unpin)   shift; cmd_unpin "$@" ;;
    export)  shift; cmd_export "$@" ;;
    import)  shift; cmd_import "$@" ;;
    current) cmd_current ;;
    -h|--help|help) usage ;;
    "")      cmd_interactive ;;
    *)       echo "Unknown command: $1" >&2; usage; exit 1 ;;
esac
