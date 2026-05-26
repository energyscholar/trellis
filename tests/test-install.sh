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

errors=0

# Verify structure
for f in config.yaml directives.md memory/MEMORY.md memory/protocol.md memory/corrections.md; do
    if [ ! -f "$TRELLIS_HOME/$f" ]; then
        echo "Missing after install: $f" >&2
        errors=$((errors + 1))
    fi
done

# Scripts executable
for s in "$TRELLIS_HOME"/scripts/*.sh; do
    [ -f "$s" ] || continue
    if [ ! -x "$s" ]; then
        echo "Not executable: $s" >&2
        errors=$((errors + 1))
    fi
done

# memory-sync.sh should be no-op (nothing changed)
bash "$TRELLIS_HOME/scripts/memory-sync.sh" 2>/dev/null || {
    echo "memory-sync.sh failed" >&2
    errors=$((errors + 1))
}

# health-check.sh should run
bash "$TRELLIS_HOME/scripts/health-check.sh" >/dev/null 2>&1 || {
    echo "health-check.sh failed" >&2
    errors=$((errors + 1))
}

# topology-check.sh should report full
output=$(bash "$TRELLIS_HOME/scripts/topology-check.sh" 2>/dev/null)
if ! echo "$output" | grep -q 'FULL'; then
    echo "topology-check not FULL: $output" >&2
    errors=$((errors + 1))
fi

# assemble-directives.sh should produce output with plugin content
output=$(bash "$TRELLIS_HOME/scripts/assemble-directives.sh" 2>/dev/null)
if ! echo "$output" | grep -q 'Storm Protocol'; then
    echo "assemble-directives missing DN content" >&2
    errors=$((errors + 1))
fi
if ! echo "$output" | grep -q 'Drift detection'; then
    echo "assemble-directives missing Triad content" >&2
    errors=$((errors + 1))
fi

exit "$errors"
