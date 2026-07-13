#!/usr/bin/env bash
# restore.sh — the one recovery command. See RECOVERY.md (Path A).
#
# Runs, in order, idempotently (safe to re-run on a healthy install):
#   1. github-setup.sh --recover   pull memory from the private repo
#   2. trellis-update.sh           replace scripts with current distribution
#                                  (the private repo carries whatever scripts
#                                  were last committed — possibly stale)
#   3. install-hooks.sh            arm the memory deletion wall
#   4. wire-platform.sh            print the platform activation block
#   5. health-check.sh             verify the six marks of health
#
# Never assumes a branch name. Never regenerates memory from any derived
# artifact — memory comes only from the private repo's flat files.
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
SCRIPTS="$TRELLIS/scripts"

if [ ! -d "$TRELLIS" ]; then
    echo "Trellis not found at $TRELLIS." >&2
    echo "Install the skeleton first (docs/install.md), then re-run restore.sh." >&2
    exit 1
fi

step() { echo ""; echo "=== restore: $1 ==="; }

step "1/5 recover memory from private repo (github-setup.sh --recover)"
if ! bash "$SCRIPTS/github-setup.sh" --recover; then
    echo "" >&2
    echo "RESTORE HALTED: memory was NOT recovered from the remote." >&2
    echo "Fix the cause above (gh auth? network? repo name?) and re-run restore.sh." >&2
    exit 1
fi

step "2/5 update scripts to current distribution (trellis-update.sh)"
bash "$SCRIPTS/trellis-update.sh" \
    || echo "WARNING: update failed (offline?). Continuing with the scripts restored from backup — re-run restore.sh when online." >&2

step "3/5 arm the deletion wall (install-hooks.sh)"
bash "$SCRIPTS/install-hooks.sh" \
    || echo "WARNING: wall not armed. Run scripts/install-hooks.sh manually." >&2

step "4/5 platform wiring (wire-platform.sh)"
echo "Add the following block to your platform file (machine-local, not restored from the repo):"
echo ""
bash "$SCRIPTS/wire-platform.sh" \
    || echo "WARNING: wire-platform.sh failed. Wire the platform file manually (see RECOVERY.md)." >&2

step "5/5 health check"
bash "$SCRIPTS/health-check.sh"
