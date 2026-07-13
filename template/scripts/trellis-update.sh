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

# Portable in-place sed (bare `sed -i` is GNU-only; BSD sed requires a suffix)
sed_inplace() {
    local expr="$1" file="$2" tmp
    tmp=$(mktemp)
    sed "$expr" "$file" > "$tmp" && mv "$tmp" "$file"
}

TEMP="/tmp/trellis-update-$$"
cleanup() { rm -rf "$TEMP" "$TRELLIS/scripts.new" "$TRELLIS/plugins.new"; }
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

# STAGE-AND-SWAP. Never `rm -rf scripts/` before the copy: a crash in that
# window leaves an install with NO SCRIPTS AT ALL, and any armed git hooks
# (the memory deletion wall) vanish mid-flight. Stage the new trees fully,
# then swap with mv — the install always has a complete scripts/ directory.
rm -rf "$TRELLIS/scripts.new" "$TRELLIS/plugins.new"
cp -r "$TEMP/template/scripts" "$TRELLIS/scripts.new"
cp -r "$TEMP/template/plugins" "$TRELLIS/plugins.new"
chmod +x "$TRELLIS/scripts.new/"*.sh
chmod +x "$TRELLIS/scripts.new/git-hooks/"* 2>/dev/null || true

rm -rf "$TRELLIS/scripts.old" "$TRELLIS/plugins.old"
mv "$TRELLIS/scripts" "$TRELLIS/scripts.old"
mv "$TRELLIS/scripts.new" "$TRELLIS/scripts"
mv "$TRELLIS/plugins" "$TRELLIS/plugins.old"
mv "$TRELLIS/plugins.new" "$TRELLIS/plugins"
rm -rf "$TRELLIS/scripts.old" "$TRELLIS/plugins.old"

cp "$TEMP/template/directives.md" "$TRELLIS/directives-base.md"
[ -f "$TEMP/template/.gitignore" ] && cp "$TEMP/template/.gitignore" "$TRELLIS/.gitignore"
[ -f "$TEMP/template/RECOVERY.md" ] && cp "$TEMP/template/RECOVERY.md" "$TRELLIS/RECOVERY.md"
[ -f "$TEMP/template/BOOTSTRAP.md" ] && cp "$TEMP/template/BOOTSTRAP.md" "$TRELLIS/BOOTSTRAP.md"

# Stamp the new version into the user's config. Without this the version gate
# never advances and every future run re-applies the same update.
sed_inplace "s|^version:.*|version: ${NEW_VERSION}|" "$TRELLIS/config.yaml"

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

# FINAL STEP: re-arm the deletion wall. core.hooksPath is local git config and
# the freshly swapped scripts/ must be re-activated after every update.
if [ -x "$TRELLIS/scripts/install-hooks.sh" ]; then
    bash "$TRELLIS/scripts/install-hooks.sh" || echo "Warning: install-hooks.sh failed — wall not armed." >&2
fi

echo "Updated: v${OLD_VERSION} → v${NEW_VERSION}" >&2
echo "  scripts/    — replaced (staged swap)" >&2
echo "  plugins/    — replaced" >&2
echo "  directives  — reassembled" >&2
echo "  config      — version stamped: ${NEW_VERSION}" >&2
echo "  wall        — install-hooks.sh run" >&2
