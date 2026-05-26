#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
T="$REPO/template"
errors=0

check() {
    if [ ! -f "$1" ]; then
        echo "MISSING: $1" >&2
        errors=$((errors + 1))
    fi
}

check "$T/config.yaml"
check "$T/directives.md"
check "$T/memory/MEMORY.md"
check "$T/memory/protocol.md"
check "$T/memory/corrections.md"

# All scripts executable
for s in "$T"/scripts/*.sh; do
    [ -f "$s" ] || continue
    if [ ! -x "$s" ]; then
        echo "NOT EXECUTABLE: $s" >&2
        errors=$((errors + 1))
    fi
done

# All plugin directories have plugin.yaml
for d in "$T"/plugins/*/; do
    [ -d "$d" ] || continue
    if [ ! -f "$d/plugin.yaml" ]; then
        echo "MISSING MANIFEST: $d" >&2
        errors=$((errors + 1))
    fi
done

# Config parses as YAML
python3 -c "import yaml; yaml.safe_load(open('$T/config.yaml'))" 2>/dev/null || {
    echo "config.yaml YAML parse failed" >&2
    errors=$((errors + 1))
}

exit "$errors"
