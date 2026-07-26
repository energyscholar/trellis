#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

if ! command -v python3 >/dev/null 2>&1; then
    echo "Missing test dependency: python3" >&2
    exit 2
fi

if ! python3 -c 'import yaml' >/dev/null 2>&1; then
    echo "Missing test dependency: PyYAML" >&2
    echo "Install it with: python3 -m pip install -r \"$REPO_DIR/requirements-test.txt\"" >&2
    exit 2
fi

passed=0
failed=0
total=0

for test in "$SCRIPT_DIR"/test-*.sh; do
    [ -f "$test" ] || continue
    name=$(basename "$test")
    total=$((total + 1))

    if bash "$test" >/dev/null 2>&1; then
        echo "  PASS  $name"
        passed=$((passed + 1))
    else
        echo "  FAIL  $name"
        failed=$((failed + 1))
    fi
done

echo ""
echo "$passed/$total passed"
[ "$failed" -gt 0 ] && exit 1 || exit 0
