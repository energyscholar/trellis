#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
T="$REPO/template"
errors=0

python3 -c "
import yaml, sys
c = yaml.safe_load(open('$T/config.yaml'))
required = ['version', 'storage', 'memory', 'plugins', 'topology', 'identity']
for key in required:
    if key not in c:
        print(f'Missing top-level key: {key}', file=sys.stderr)
        sys.exit(1)

# topology.threshold must be a number
t = c.get('topology', {}).get('threshold')
if not isinstance(t, (int, float)):
    print(f'topology.threshold is not a number: {t}', file=sys.stderr)
    sys.exit(1)

# All active plugins have valid directories
for p in c.get('plugins', {}).get('active', []):
    import os
    if not os.path.isdir(f'$T/plugins/{p}'):
        print(f'Plugin directory missing for active plugin: {p}', file=sys.stderr)
        sys.exit(1)
" || errors=$((errors + 1))

exit "$errors"
