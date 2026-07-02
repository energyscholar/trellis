#!/usr/bin/env bash
set -euo pipefail

# github-setup.sh — Configure a private GitHub repo for Trellis memory backup.
#
# Usage:
#   github-setup.sh                   Fresh setup or reconnect
#   github-setup.sh --recover         Recovery mode: restore memory from existing repo
#   github-setup.sh --repo-name NAME  Use a custom repo name (default: trellis-memory)
#
# Idempotent: safe to run multiple times. If already configured, exits early.

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

# DISTRIBUTION REPO GUARD: refuse to run if this is the distribution repo
if [ -f "$TRELLIS/.trellis-distribution" ]; then
    echo "REFUSED: This is the Trellis distribution repo, not your install." >&2
    echo "Install first: copy template/ to ~/.trellis/ (see docs/install.md)" >&2
    exit 1
fi
if [ -d "$TRELLIS/template" ] && [ -d "$TRELLIS/tests" ]; then
    echo "REFUSED: This looks like the distribution repo (has template/ and tests/)." >&2
    echo "Install first: copy template/ to ~/.trellis/ (see docs/install.md)" >&2
    exit 1
fi

# --- Parse flags ---
RECOVER=false
REPO_NAME=""
while [ $# -gt 0 ]; do
    case "$1" in
        --recover)    RECOVER=true ;;
        --repo-name)  shift; REPO_NAME="${1:-}" ;;
        *)            echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

config="$TRELLIS/config.yaml"

# --- Early exit if already configured ---
if [ -f "$TRELLIS/.github-setup-complete" ] && ! $RECOVER; then
    # Verify the remote is actually set
    cd "$TRELLIS"
    if git remote get-url origin &>/dev/null; then
        echo "Already configured. Remote: $(git remote get-url origin)"
        exit 0
    fi
    # Marker exists but remote is gone — fall through to re-setup
    rm -f "$TRELLIS/.github-setup-complete"
fi

# --- Check gh CLI ---
if ! command -v gh &>/dev/null; then
    echo "GitHub CLI (gh) is not installed." >&2
    echo "Install: https://cli.github.com/" >&2
    echo "  macOS:  brew install gh" >&2
    echo "  Linux:  sudo apt install gh  (or see link above)" >&2
    exit 1
fi

# --- Check gh auth ---
if ! gh auth status &>/dev/null 2>&1; then
    echo "GitHub CLI is not authenticated." >&2
    echo "Run:  gh auth login" >&2
    echo "Then re-run this script." >&2
    exit 1
fi

# --- Get GitHub username ---
GH_USER=$(gh api user --jq '.login' 2>/dev/null) || true
if [ -z "$GH_USER" ]; then
    echo "Could not determine GitHub username." >&2
    echo "Check:  gh auth status" >&2
    exit 1
fi

# --- Determine repo name ---
if [ -z "$REPO_NAME" ]; then
    # Try config.yaml
    REPO_NAME=$(grep -E '^\s*repo_name:' "$config" 2>/dev/null \
        | head -1 | sed 's/.*repo_name:[[:space:]]*//' | tr -d '"' | tr -d "'" | tr -d '\r') || true
fi
if [ -z "$REPO_NAME" ]; then
    REPO_NAME="trellis-memory"
fi

REMOTE_URL="https://github.com/$GH_USER/$REPO_NAME.git"

echo "GitHub user: $GH_USER"
echo "Repo name:   $REPO_NAME"

# --- Check if repo exists on GitHub ---
repo_exists=false
if gh repo view "$GH_USER/$REPO_NAME" &>/dev/null 2>&1; then
    repo_exists=true
fi

cd "$TRELLIS"

# --- Ensure local git initialized ---
if ! git rev-parse --git-dir &>/dev/null 2>&1; then
    git init
    git add -A
    git commit -m "Trellis initial install" 2>/dev/null || true
fi

if $repo_exists; then
    if $RECOVER; then
        # Recovery mode: pull memory from existing repo
        echo "Recovery mode: restoring from $GH_USER/$REPO_NAME..."
        tmpdir=$(mktemp -d)
        trap 'rm -rf "$tmpdir"' EXIT

        git clone "$REMOTE_URL" "$tmpdir/restore"

        # Restore memory and config from backup
        if [ -d "$tmpdir/restore/memory" ]; then
            cp -r "$tmpdir/restore/memory/"* "$TRELLIS/memory/" 2>/dev/null || true
            echo "  Restored memory/"
        fi
        if [ -f "$tmpdir/restore/config.yaml" ]; then
            cp "$tmpdir/restore/config.yaml" "$config"
            echo "  Restored config.yaml"
        fi
        if [ -d "$tmpdir/restore/profiles" ]; then
            cp -r "$tmpdir/restore/profiles/"* "$TRELLIS/profiles/" 2>/dev/null || true
            echo "  Restored profiles/"
        fi

        rm -rf "$tmpdir"
        trap - EXIT
        echo "Memory restored from backup."
    else
        # Repo exists, not recovery — reconnect (multi-machine scenario)
        echo "Existing repo found. Reconnecting..."
    fi
fi

# --- Set remote ---
git remote remove origin 2>/dev/null || true
git remote add origin "$REMOTE_URL"

if ! $repo_exists; then
    # Create new private repo
    echo "Creating private repo: $GH_USER/$REPO_NAME..."
    if ! gh repo create "$REPO_NAME" --private --description "Trellis memory (private, auto-managed)" 2>/dev/null; then
        echo "Failed to create repo. Check GitHub access and try again." >&2
        exit 1
    fi
    echo "Repo created."
fi

# --- Update config.yaml ---
sed -i "s|^\(\s*tier:\s*\).*|\1 2|" "$config"
sed -i "s|^\(\s*remote_url:\s*\).*|\1 \"$REMOTE_URL\"|" "$config"
sed -i "s|^\(\s*auto_push:\s*\).*|\1 true|" "$config"
sed -i "s|^\(\s*auto_pull:\s*\).*|\1 true|" "$config"

# --- Initial commit + push ---
git add -A
git commit -m "Trellis: GitHub backup configured" 2>/dev/null || true

if $repo_exists; then
    # Fetch and merge before pushing (multi-machine or recovery)
    git fetch origin main 2>/dev/null || true
    git pull --rebase origin main 2>/dev/null || true
fi

if git push -u origin main 2>/dev/null; then
    # --- Create marker ---
    touch "$TRELLIS/.github-setup-complete"
    echo ""
    echo "GitHub backup configured successfully."
    echo "  Repo: https://github.com/$GH_USER/$REPO_NAME"
    echo "  Memories will sync automatically on session end."
    echo "  Recovery: git clone $REMOTE_URL ~/.trellis"
else
    echo ""
    echo "Warning: push failed (network issue?). Setup incomplete." >&2
    echo "Re-run this script when connectivity is restored." >&2
    exit 1
fi
