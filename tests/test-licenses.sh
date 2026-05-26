#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
errors=0

# MIT license exists
if [ ! -f "$REPO/LICENSE" ]; then
    echo "LICENSE (MIT) missing" >&2
    errors=$((errors + 1))
fi

# DN license exists
if [ ! -f "$REPO/LICENSE-DN.md" ]; then
    echo "LICENSE-DN.md missing" >&2
    errors=$((errors + 1))
fi

# DN plugin files have copyright header
for f in "$REPO"/template/plugins/dignity-net/*.md; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    [ "$base" = "directives.md" ] && continue
    if ! grep -q 'Genevieve Prentice' "$f"; then
        echo "DN copyright missing in: $f" >&2
        errors=$((errors + 1))
    fi
done

# No DN-licensed content outside plugins/dignity-net/
dn_outside=$(grep -rl 'Dignity Net License' "$REPO/template/" 2>/dev/null | grep -v 'plugins/dignity-net/' | grep -v 'config.yaml' || true)
if [ -n "$dn_outside" ]; then
    echo "DN-licensed content outside dignity-net plugin: $dn_outside" >&2
    errors=$((errors + 1))
fi

exit "$errors"
