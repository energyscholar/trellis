#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

if ! command -v python3 >/dev/null 2>&1; then
    echo "Missing test dependency: python3" >&2
    exit 2
fi

if ! python3 -c 'import yaml' >/dev/null 2>&1; then
    # Plain pip install is refused on externally-managed interpreters (PEP 668:
    # Debian 12+, Ubuntu 23.04+, Homebrew Python), which is exactly where a new
    # contributor lands first. Offer a route that works there too.
    echo "Missing test dependency: PyYAML" >&2
    echo "" >&2
    echo "Install it one of these ways:" >&2
    echo "  python3 -m pip install -r \"$REPO_DIR/requirements-test.txt\"" >&2
    echo "  # if that reports 'externally-managed-environment' (PEP 668):" >&2
    echo "  sudo apt install python3-yaml          # Debian/Ubuntu system package" >&2
    echo "  brew install libyaml && pip3 install --user PyYAML   # macOS/Homebrew" >&2
    echo "  # or use a virtualenv:" >&2
    echo "  python3 -m venv .venv && .venv/bin/pip install -r \"$REPO_DIR/requirements-test.txt\"" >&2
    echo "  PATH=\"\$PWD/.venv/bin:\$PATH\" bash tests/run-all.sh" >&2
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
