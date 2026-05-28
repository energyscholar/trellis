#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

export TRELLIS_HOME="$TMPDIR/trellis"

# Simulate install: copy template
cp -r "$REPO/template/" "$TRELLIS_HOME/"

# Init git
cd "$TRELLIS_HOME"
git init -q
git config user.name "Trellis Test"
git config user.email "test@local"
git add -A
git commit -q -m "Initial install"

PROFILE="$TRELLIS_HOME/scripts/trellis-profile.sh"
errors=0

# 1. Save a profile
bash "$PROFILE" save test-a -d "Test profile" || {
    echo "FAIL: save test-a" >&2
    errors=$((errors + 1))
}

# 2. Verify directory exists
if [ ! -d "$TRELLIS_HOME/profiles/test-a" ]; then
    echo "FAIL: profiles/test-a/ missing" >&2
    errors=$((errors + 1))
fi

# 3. Pin test-a
bash "$PROFILE" pin test-a || {
    echo "FAIL: pin test-a" >&2
    errors=$((errors + 1))
}

# 4. Save to pinned profile should fail
if bash "$PROFILE" save test-a -d "Overwrite" 2>/dev/null; then
    echo "FAIL: save to pinned profile should fail" >&2
    errors=$((errors + 1))
fi

# 5. Delete of pinned profile should fail
if bash "$PROFILE" delete test-a 2>/dev/null; then
    echo "FAIL: delete of pinned profile should fail" >&2
    errors=$((errors + 1))
fi

# 6. Export test-a
bash "$PROFILE" export test-a "$TMPDIR/test-a.trellis-profile.tar.gz" || {
    echo "FAIL: export test-a" >&2
    errors=$((errors + 1))
}

# 7. Verify tarball exists
if [ ! -f "$TMPDIR/test-a.trellis-profile.tar.gz" ]; then
    echo "FAIL: tarball missing" >&2
    errors=$((errors + 1))
fi

# 8. Import as test-b
bash "$PROFILE" import "$TMPDIR/test-a.trellis-profile.tar.gz" test-b || {
    echo "FAIL: import as test-b" >&2
    errors=$((errors + 1))
}

# 9. Verify profiles/test-b/ exists
if [ ! -d "$TRELLIS_HOME/profiles/test-b" ]; then
    echo "FAIL: profiles/test-b/ missing" >&2
    errors=$((errors + 1))
fi

# 10. Verify same file count in memory/
count_a=$(find "$TRELLIS_HOME/profiles/test-a/memory" -type f | wc -l)
count_b=$(find "$TRELLIS_HOME/profiles/test-b/memory" -type f | wc -l)
if [ "$count_a" -ne "$count_b" ]; then
    echo "FAIL: memory file count mismatch (test-a=$count_a, test-b=$count_b)" >&2
    errors=$((errors + 1))
fi

# 11. Load test-b
bash "$PROFILE" load test-b || {
    echo "FAIL: load test-b" >&2
    errors=$((errors + 1))
}

# 12. Verify active profile
active=$(bash "$PROFILE" current)
if [ "$active" != "test-b" ]; then
    echo "FAIL: active profile is '$active', expected 'test-b'" >&2
    errors=$((errors + 1))
fi

# 13. Unpin test-a
bash "$PROFILE" unpin test-a || {
    echo "FAIL: unpin test-a" >&2
    errors=$((errors + 1))
}

# 14. Delete test-a
bash "$PROFILE" delete test-a || {
    echo "FAIL: delete test-a" >&2
    errors=$((errors + 1))
}

# 15. Verify test-a is gone
if [ -d "$TRELLIS_HOME/profiles/test-a" ]; then
    echo "FAIL: profiles/test-a/ still exists" >&2
    errors=$((errors + 1))
fi

# 16. List should contain test-b
list_output=$(bash "$PROFILE" list)
if ! echo "$list_output" | grep -q "test-b"; then
    echo "FAIL: list output missing test-b" >&2
    errors=$((errors + 1))
fi

exit "$errors"
