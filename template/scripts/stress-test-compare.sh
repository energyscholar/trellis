#!/usr/bin/env bash
set -euo pipefail

# stress-test-compare.sh — Compare ACS state across all profiles without loading them.
# Non-destructive: uses TRELLIS_HOME env var to point acs-check at each profile directory.

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

echo "Trellis Profile Comparison"
echo "=========================="
echo ""
printf "  %-20s  %4s  %5s  %5s  %-14s  %-14s\n" "Profile" "Sess" "λ₁" "Gap" "Weakest" "Status"
printf "  %-20s  %4s  %5s  %5s  %-14s  %-14s\n" "--------------------" "----" "-----" "-----" "--------------" "--------------"

for profile_dir in "$PROFILES_DIR"/*/; do
    [ -d "$profile_dir" ] || continue
    name=$(basename "$profile_dir")

    # Skip internal profiles
    [[ "$name" == "_autosave" ]] && continue

    # Check if profile has memory dir with session-log
    if [ ! -d "$profile_dir/memory" ]; then
        printf "  %-20s  %4s  %5s  %5s  %-14s  %-14s\n" "$name" "--" "--" "--" "--" "NO MEMORY DIR"
        continue
    fi

    # Count sessions from session-log
    sessions=0
    if [ -f "$profile_dir/memory/session-log.md" ]; then
        sessions=$(grep -cE '^\| S[0-9]' "$profile_dir/memory/session-log.md" 2>/dev/null) || sessions=0
    fi

    # Run ACS check against profile directory (non-destructive)
    acs_line=$(TRELLIS_HOME="$profile_dir" ACS_MIN_SESSIONS=0 bash "$TRELLIS/scripts/acs-check.sh" --oneliner 2>/dev/null || echo "  acs: ERROR")

    # Parse the oneliner — handle UTF-8 λ and multi-byte arrow characters
    lambda=$(echo "$acs_line" | sed -n 's/.*λ=\([0-9.]*\).*/\1/p')
    [ -z "$lambda" ] && lambda="--"
    gap=$(echo "$acs_line" | sed -n 's/.*gap=\([0-9.]*\).*/\1/p')
    [ -z "$gap" ] && gap="--"
    weak=$(echo "$acs_line" | sed -n 's/.*weak=\([^ ]*\).*/\1/p')
    [ -z "$weak" ] && weak="--"
    status=$(echo "$acs_line" | sed -n 's/.*\[\([A-Z-]*\)\].*/\1/p')
    [ -z "$status" ] && status="--"

    # Mark active profile
    current_profile=$(bash "$TRELLIS/scripts/trellis-profile.sh" current 2>/dev/null || echo "")
    marker=" "
    [ "$name" = "$current_profile" ] && marker="*"

    # Mark pinned
    pinned=""
    if [ -f "$profile_dir/profile.yaml" ] && grep -q "pinned: true" "$profile_dir/profile.yaml" 2>/dev/null; then
        pinned=" [pin]"
    fi

    printf "%s %-20s  %4s  %5s  %5s  %-14s  %-14s%s\n" "$marker" "$name" "$sessions" "$lambda" "$gap" "$weak" "$status" "$pinned"
done

echo ""

# Show current active profile
current=$(bash "$TRELLIS/scripts/trellis-profile.sh" current 2>/dev/null || echo "unknown")
echo "  Active: $current (* in list)"
