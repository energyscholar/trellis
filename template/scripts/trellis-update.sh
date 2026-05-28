#!/usr/bin/env bash
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

if [ ! -d "$TRELLIS" ]; then
    echo "Trellis not found at $TRELLIS" >&2
    exit 1
fi

if [ -f "$TRELLIS/.trellis-distribution" ]; then
    echo "REFUSED: This is the Trellis distribution repo, not your install." >&2
    exit 1
fi
if [ -d "$TRELLIS/template" ] && [ -d "$TRELLIS/tests" ]; then
    echo "REFUSED: This looks like the distribution repo (has template/ and tests/)." >&2
    exit 1
fi

CHECK_ONLY=false
for arg in "$@"; do
    case "$arg" in
        --check) CHECK_ONLY=true ;;
    esac
done

REPO_URL=$(grep -E '^\s*repo_url:' "$TRELLIS/config.yaml" 2>/dev/null \
    | head -1 | sed 's/.*repo_url:[[:space:]]*//' | tr -d '\r"'"'" || true)
: "${REPO_URL:=https://github.com/energyscholar/trellis.git}"

TEMP="/tmp/trellis-update-$$"
cleanup() { rm -rf "$TEMP"; }
trap cleanup EXIT

echo "Fetching updates from $REPO_URL..." >&2
if ! git clone --depth 1 -q "$REPO_URL" "$TEMP" 2>/dev/null; then
    echo "Could not reach update server. Check your internet connection." >&2
    exit 1
fi

if [ ! -f "$TEMP/template/config.yaml" ] || [ ! -d "$TEMP/template/scripts" ]; then
    echo "Downloaded repo doesn't look like Trellis." >&2
    exit 1
fi

NEW_VERSION=$(grep -E '^\s*version:' "$TEMP/template/config.yaml" | head -1 \
    | sed 's/.*version:[[:space:]]*//' | tr -d '\r"'"'")
OLD_VERSION=$(grep -E '^\s*version:' "$TRELLIS/config.yaml" | head -1 \
    | sed 's/.*version:[[:space:]]*//' | tr -d '\r"'"'")

if [ "$OLD_VERSION" = "$NEW_VERSION" ]; then
    echo "Already up to date (v${OLD_VERSION})." >&2
    exit 0
fi

if $CHECK_ONLY; then
    echo "Update available: v${OLD_VERSION} → v${NEW_VERSION}" >&2
    exit 0
fi

if [ ! -f "$TRELLIS/config.yaml" ] || [ ! -d "$TRELLIS/memory" ]; then
    echo "Install directory doesn't look like Trellis (missing config.yaml or memory/)." >&2
    exit 1
fi

cd "$TRELLIS"

if git rev-parse --git-dir &>/dev/null; then
    git add -A && git commit -m "Pre-update snapshot" 2>/dev/null || true
fi

rm -rf "$TRELLIS/scripts" && cp -r "$TEMP/template/scripts" "$TRELLIS/scripts"
rm -rf "$TRELLIS/plugins" && cp -r "$TEMP/template/plugins" "$TRELLIS/plugins"
cp "$TEMP/template/directives.md" "$TRELLIS/directives-base.md"
[ -f "$TEMP/template/.gitignore" ] && cp "$TEMP/template/.gitignore" "$TRELLIS/.gitignore"

chmod +x "$TRELLIS/scripts/"*.sh

if [ -x "$TRELLIS/scripts/assemble-directives.sh" ]; then
    bash "$TRELLIS/scripts/assemble-directives.sh" --write 2>/dev/null || true
fi

if git rev-parse --git-dir &>/dev/null; then
    git add -A && git commit -m "Trellis update: v${OLD_VERSION} → v${NEW_VERSION}"

    AUTO_PUSH=$(grep -E '^\s*auto_push:' "$TRELLIS/config.yaml" 2>/dev/null \
        | head -1 | sed 's/.*auto_push:[[:space:]]*//' | tr -d '\r' || true)
    if [ "$AUTO_PUSH" = "true" ] && git remote get-url origin &>/dev/null; then
        git push 2>/dev/null || echo "Warning: push failed (offline?). Local commit preserved." >&2
    fi
fi

echo "Updated: v${OLD_VERSION} → v${NEW_VERSION}" >&2
echo "  scripts/    — replaced" >&2
echo "  plugins/    — replaced" >&2
echo "  directives  — reassembled" >&2
