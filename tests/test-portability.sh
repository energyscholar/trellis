#!/usr/bin/env bash
# test-portability.sh — lint template/scripts for GNU-only constructs that
# break macOS (bash 3.2, BSD userland). Fails on any hit so regressions
# cannot ship:
#   grep -P      PCRE is GNU grep only; on macOS extraction returns EMPTY
#   md5sum       macOS ships md5/shasum, not md5sum
#   stat -c      BSD stat wants -f (and GNU `stat -f` means something else)
#   date -d      BSD date has no -d; use --date=@/date -r via a wrapper
#   bare sed -i  BSD sed requires a suffix argument after -i
#   realpath     pre-Ventura macOS lacks it; use cd/pwd -P
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS="$REPO/template/scripts"
errors=0

lint() {
    local pattern="$1" label="$2" hits
    # Full-line comments are allowed to NAME the offending construct
    # (that is how scripts document why the portable form is used).
    hits=$(grep -RnE "$pattern" "$SCRIPTS" --include='*.sh' 2>/dev/null \
        | grep -vE '^[^:]*:[0-9]+:[[:space:]]*#' || true)
    # git hooks have no .sh extension — lint them too
    hits="$hits$(grep -RnE "$pattern" "$SCRIPTS/git-hooks" 2>/dev/null \
        | grep -vE '^[^:]*:[0-9]+:[[:space:]]*#' || true)"
    if [ -n "$hits" ]; then
        echo "PORTABILITY: $label found:" >&2
        echo "$hits" >&2
        errors=$((errors + 1))
    fi
}

lint 'grep[[:space:]]+-[A-Za-z]*P' 'grep -P (GNU-only PCRE)'
lint '\bmd5sum\b' 'md5sum (GNU-only; use shasum -a 256)'
lint 'stat[[:space:]]+-c' 'stat -c (GNU-only; use a stat wrapper)'
lint 'date[[:space:]]+(-[A-Za-z]+[[:space:]]+)*-d[[:space:]"]' 'date -d (GNU-only)'
lint 'sed[[:space:]]+(-[A-Za-z]+[[:space:]]+)*-i([[:space:]]|$|'"'"')' 'bare sed -i (BSD sed needs a suffix; use sed_inplace)'
lint '\brealpath\b' 'realpath (missing on older macOS; use cd/pwd -P)'

if [ "$errors" -eq 0 ]; then
    echo "portability lint: clean"
fi
exit "$errors"
