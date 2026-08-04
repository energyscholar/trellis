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

# The shipped DN spec must point to Trellis's DN license, never the canonical
# repository's differently named LICENSE.md or Trellis's MIT LICENSE.
dn_spec="$REPO/template/plugins/dignity-net/dignity-net.md"
if ! head -1 "$dn_spec" | grep -Fq 'See LICENSE-DN.md'; then
    echo "DN spec header does not point to LICENSE-DN.md" >&2
    errors=$((errors + 1))
fi
if grep -Fq 'LICENSE.md' "$dn_spec"; then
    echo "DN spec points to missing LICENSE.md instead of LICENSE-DN.md" >&2
    errors=$((errors + 1))
fi

# No DN-licensed content outside plugins/dignity-net/
dn_outside=$(grep -rl 'Dignity Net License' "$REPO/template/" 2>/dev/null | grep -v 'plugins/dignity-net/' | grep -v 'config.yaml' || true)
if [ -n "$dn_outside" ]; then
    echo "DN-licensed content outside dignity-net plugin: $dn_outside" >&2
    errors=$((errors + 1))
fi

exit "$errors"
