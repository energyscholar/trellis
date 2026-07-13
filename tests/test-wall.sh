#!/usr/bin/env bash
# test-wall.sh — the memory deletion wall blocks de-indexing motions.
# Verifies: git rm blocked, git mv into memory/archive/ blocked, in-place
# rename allowed, ALLOW_MEMORY_DELETE=1 override works and is logged.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

export TRELLIS_HOME="$TMPDIR/trellis"

# Simulate install
cp -r "$REPO/template/" "$TRELLIS_HOME/"
cd "$TRELLIS_HOME"
git init -q
git config user.name "Trellis Test"
git config user.email "test@local"
git add -A
git commit -q -m "Initial install"

errors=0

# Arm the wall
bash "$TRELLIS_HOME/scripts/install-hooks.sh" >/dev/null || {
    echo "FAIL: install-hooks.sh failed" >&2
    errors=$((errors + 1))
}
if [ "$(git config core.hooksPath)" != "scripts/git-hooks" ]; then
    echo "FAIL: core.hooksPath not armed" >&2
    errors=$((errors + 1))
fi

# Seed a memory file
cat > memory/wall-test.md <<'EOF'
---
type: feedback
description: wall test fixture
---
This file exists to test the deletion wall. It has enough content that
git rename detection recognizes an in-place rename as a rename.
EOF
git add memory/wall-test.md
git commit -q -m "Add wall test memory"

# 1. git rm must be BLOCKED
git rm -q memory/wall-test.md
if git commit -q -m "delete memory" 2>/dev/null; then
    echo "FAIL: commit deleting memory/*.md was NOT blocked" >&2
    errors=$((errors + 1))
    git revert -n HEAD >/dev/null 2>&1 || true
fi
git reset -q --hard HEAD

# 2. git mv into memory/archive/ must be BLOCKED (de-indexing = leaving the read path)
mkdir -p memory/archive
git mv memory/wall-test.md memory/archive/wall-test.md
if git commit -q -m "archive memory" 2>/dev/null; then
    echo "FAIL: commit moving memory/*.md into memory/archive/ was NOT blocked" >&2
    errors=$((errors + 1))
fi
git reset -q --hard HEAD
rm -rf memory/archive

# 3. In-place rename must be ALLOWED
git mv memory/wall-test.md memory/wall-test-renamed.md
if ! git commit -q -m "rename memory in place" 2>/dev/null; then
    echo "FAIL: in-place rename of memory/*.md was blocked (should be allowed)" >&2
    errors=$((errors + 1))
    git reset -q --hard HEAD
fi

# 4. Override must work AND be logged
git rm -q memory/wall-test-renamed.md 2>/dev/null || git rm -q memory/wall-test.md
if ! ALLOW_MEMORY_DELETE=1 MEMORY_DELETE_REASON="wall self-test" git commit -q -m "deliberate delete" 2>/dev/null; then
    echo "FAIL: ALLOW_MEMORY_DELETE=1 override did not permit the commit" >&2
    errors=$((errors + 1))
fi
if ! grep -q "OVERRIDE.*wall self-test" health/deletion-attempts.log 2>/dev/null; then
    echo "FAIL: override was not logged to health/deletion-attempts.log" >&2
    errors=$((errors + 1))
fi

# 5. Blocked attempts must also be logged
if ! grep -q "BLOCKED" health/deletion-attempts.log 2>/dev/null; then
    echo "FAIL: blocked attempts were not logged" >&2
    errors=$((errors + 1))
fi

exit "$errors"
