#!/usr/bin/env bash
# install-hooks.sh — Activate the committed git hooks (the memory deletion wall).
# core.hooksPath is LOCAL git config, NOT stored in the repo, so it does NOT
# survive a clone. Run once per clone; health-check.sh re-arms it every run.
# Idempotent and safe to run repeatedly.
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

cd "$TRELLIS"

if ! command -v git >/dev/null 2>&1 || ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "install-hooks: no git repo at $TRELLIS (Tier 0) — wall not armed." >&2
    exit 0
fi

if [ ! -f "$TRELLIS/scripts/git-hooks/pre-commit" ]; then
    echo "install-hooks: scripts/git-hooks/pre-commit missing — run trellis-update.sh first." >&2
    exit 1
fi

git config core.hooksPath scripts/git-hooks
chmod +x scripts/git-hooks/* 2>/dev/null || true
echo "install-hooks: core.hooksPath = $(git config core.hooksPath)"
