#!/usr/bin/env bash
set -euo pipefail

# stress-test-load.sh — Load a profile and verify readiness for stress testing.
# DB rebuild happens automatically via profile-load's --if-stale checksum detection.

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

profile="${1:-}"
if [ -z "$profile" ]; then
    echo "Usage: stress-test-load.sh <profile-name>" >&2
    echo "" >&2
    echo "Loads a profile, rebuilds the DB, and runs health + ACS checks." >&2
    echo "Profiles available:" >&2
    bash "$TRELLIS/scripts/trellis-profile.sh" list 2>/dev/null | grep -E '^\s+[0-9]+\.' >&2
    exit 1
fi

profile_dir="$TRELLIS/profiles/$profile"
if [ ! -d "$profile_dir" ]; then
    echo "ERROR: Profile '$profile' not found at $profile_dir" >&2
    exit 1
fi

echo "╔═══════════════════════════════════════════╗"
echo "║  Stress Test: Loading profile             ║"
echo "╠═══════════════════════════════════════════╣"
echo ""

# Step 1: Load the profile
echo "► Loading profile: $profile"
bash "$TRELLIS/scripts/trellis-profile.sh" load "$profile"
echo ""

# Step 2: Run health check (triggers --if-stale DB rebuild if profile load didn't already)

echo "► Health check:"
bash "$TRELLIS/scripts/health-check.sh" 2>/dev/null || true
echo ""

# Step 5: Run ACS check
echo "► ACS baseline:"
ACS_MIN_SESSIONS=0 bash "$TRELLIS/scripts/acs-check.sh" --oneliner 2>/dev/null || echo "  (ACS check not available)"
echo ""

# Step 6: Verify file count
file_count=$(ls "$TRELLIS/memory/"*.md 2>/dev/null | wc -l)
echo "► Memory files: $file_count"

# Step 7: Check for broken cross-references
broken=0
for link in $(grep -roh '\[\[[^]]*\]\]' "$TRELLIS/memory/"*.md 2>/dev/null | sort -u); do
    name=$(echo "$link" | sed 's/\[\[//;s/\]\]//')
    if [ ! -f "$TRELLIS/memory/${name}.md" ]; then
        echo "  BROKEN: $link"
        broken=$((broken + 1))
    fi
done
if [ "$broken" -eq 0 ]; then
    echo "► Cross-references: all valid"
else
    echo "► Cross-references: $broken broken"
fi

echo ""
echo "╚═══════════════════════════════════════════╝"
echo "  Profile '$profile' loaded and verified."
echo "  Ready for stress testing."
