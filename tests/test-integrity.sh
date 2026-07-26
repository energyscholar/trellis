#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
T="$REPO/template"
errors=0

# Run a YAML extractor and fail loudly if it cannot run.
#
# These checks used to pipe python3 output straight into `for`, with stderr
# redirected to /dev/null. A missing PyYAML then produced an empty list, the
# loop body never ran, and the test PASSED without checking anything — a green
# result meaning "skipped", which is worse than a red one. Every extraction now
# goes through here so an unusable interpreter is a failure, not a silent skip.
yaml_extract() {
    local out status
    out=$(python3 -c "$1" 2>&1) || status=$?
    if [ -n "${status:-}" ]; then
        echo "YAML extraction failed (integrity checks cannot run):" >&2
        echo "$out" >&2
        return 1
    fi
    printf '%s\n' "$out"
}

# All plugins listed in config.yaml have directories
plugin_list=$(yaml_extract "
import yaml
c = yaml.safe_load(open('$T/config.yaml'))
for p in c.get('plugins', {}).get('active', []):
    print(p)
") || exit 1

for plugin in $plugin_list; do
    if [ ! -d "$T/plugins/$plugin" ]; then
        echo "Plugin directory missing: $plugin" >&2
        errors=$((errors + 1))
    fi
done

# All files listed in plugin.yaml exist
manifests_checked=0
for manifest in "$T"/plugins/*/plugin.yaml; do
    [ -f "$manifest" ] || continue
    manifests_checked=$((manifests_checked + 1))
    dir=$(dirname "$manifest")
    file_list=$(yaml_extract "
import yaml
m = yaml.safe_load(open('$manifest'))
for v in m.get('files', {}).values():
    print(v)
") || exit 1

    for f in $file_list; do
        if [ ! -f "$dir/$f" ]; then
            echo "Plugin file missing: $dir/$f" >&2
            errors=$((errors + 1))
        fi
    done
done

# A repo with plugin manifests that checked none of them has skipped its work.
manifest_count=$(find "$T/plugins" -name plugin.yaml 2>/dev/null | wc -l | tr -d ' ')
if [ "$manifest_count" -gt 0 ] && [ "$manifests_checked" -eq 0 ]; then
    echo "Found $manifest_count plugin manifest(s) but checked none" >&2
    errors=$((errors + 1))
fi

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
