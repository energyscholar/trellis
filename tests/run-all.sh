#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

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
