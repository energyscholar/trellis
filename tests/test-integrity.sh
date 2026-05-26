#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
T="$REPO/template"
errors=0

# All plugins listed in config.yaml have directories
for plugin in $(python3 -c "
import yaml
c = yaml.safe_load(open('$T/config.yaml'))
for p in c.get('plugins', {}).get('active', []):
    print(p)
" 2>/dev/null); do
    if [ ! -d "$T/plugins/$plugin" ]; then
        echo "Plugin directory missing: $plugin" >&2
        errors=$((errors + 1))
    fi
done

# All files listed in plugin.yaml exist
for manifest in "$T"/plugins/*/plugin.yaml; do
    [ -f "$manifest" ] || continue
    dir=$(dirname "$manifest")
    for f in $(python3 -c "
import yaml
m = yaml.safe_load(open('$manifest'))
for v in m.get('files', {}).values():
    print(v)
" 2>/dev/null); do
        if [ ! -f "$dir/$f" ]; then
            echo "Plugin file missing: $dir/$f" >&2
            errors=$((errors + 1))
        fi
    done
done

# TRELLIS_HOME resolution function is identical across all scripts
canonical="resolve_trellis_home"
for s in "$T"/scripts/memory-sync.sh "$T"/scripts/health-check.sh "$T"/scripts/topology-check.sh "$T"/scripts/assemble-directives.sh "$T"/scripts/wire-platform.sh "$T"/scripts/rebuild-db.sh "$T"/scripts/ingest-memories.sh; do
    [ -f "$s" ] || continue
    if ! grep -q "$canonical" "$s"; then
        echo "Missing resolve_trellis_home in: $(basename "$s")" >&2
        errors=$((errors + 1))
    fi
done

# No personal references in template
if grep -ri 'Bruce\|Argus\|aurasys\|/home/' "$T/memory/" "$T/directives.md" "$T/scripts/"*.sh 2>/dev/null | grep -v 'plugin.yaml' | grep -v '.sql'; then
    echo "Personal references found in template" >&2
    errors=$((errors + 1))
fi

exit "$errors"
