#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

export TRELLIS_HOME="$TMPDIR/trellis"

# Install first
cp -r "$REPO/template/" "$TRELLIS_HOME/"
cd "$TRELLIS_HOME"
git init -q
git config user.name "Trellis Test"
git config user.email "test@local"
git add -A
git commit -q -m "Initial install"

# Write breadcrumb
mkdir -p "$TMPDIR/config/trellis"
echo "$TRELLIS_HOME" > "$TMPDIR/config/trellis/home"

errors=0

# Simulate uninstall: remove directory
rm -rf "$TRELLIS_HOME"

if [ -d "$TRELLIS_HOME" ]; then
    echo "Install directory still exists" >&2
    errors=$((errors + 1))
fi

# Remove breadcrumb
rm -f "$TMPDIR/config/trellis/home"

if [ -f "$TMPDIR/config/trellis/home" ]; then
    echo "Breadcrumb still exists" >&2
    errors=$((errors + 1))
fi

exit "$errors"
