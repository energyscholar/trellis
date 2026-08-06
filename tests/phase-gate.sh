#!/usr/bin/env bash
# tests/phase-gate.sh — the single command a phase must pass before it counts
# as done.
#
#   bash tests/phase-gate.sh <baseline-report-file>
#
# Baseline is a previous `tests/run-all.sh --report` output, captured at the
# start of the phase:
#
#   bash tests/run-all.sh --report > /tmp/baseline.txt
#
# It checks four things, in this order, and stops at the first failure with a
# ONE-LINE reason:
#
#   1. the suite passes with --report (asserts green, every guard proven,
#      no undeclared skip)
#   2. no count went DOWN against the baseline — files, assertions, guards
#      registered, guards proven. A phase that deletes coverage to go green
#      is the failure mode this exists to catch; a raw pass/fail cannot see it.
#   3. the working tree is clean (git status --porcelain empty)
#   4. no *.new, *.old, or leftover temp directories under the repo
#
# Portability: bash 3.2 / BSD userland.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

die() {
    printf 'PHASE GATE FAIL: %s\n' "$1" >&2
    exit 1
}

BASELINE="${1:-}"
[ -n "$BASELINE" ] || die "usage: $0 <baseline-report-file>"
[ -f "$BASELINE" ] || die "baseline report not found: $BASELINE"

WORK=$(mktemp -d "${TMPDIR:-/tmp}/trellis-phasegate.XXXXXXXX")
trap 'rm -rf "$WORK"' EXIT

# --- 1. run the suite -------------------------------------------------------
CURRENT="$WORK/report.txt"
run_rc=0
bash "$SCRIPT_DIR/run-all.sh" --report >"$CURRENT" 2>"$WORK/report.err" || run_rc=$?
if [ "$run_rc" -ne 0 ]; then
    reason=$(grep -m1 '^GATE FAIL' "$WORK/report.err" 2>/dev/null || true)
    [ -n "$reason" ] || reason="run-all.sh --report exited $run_rc"
    die "suite failed: $reason"
fi

# --- 2. no count may go down ------------------------------------------------
# Field extraction with awk, not grep -P (banned) and not sed -i (banned).
report_field() {
    # report_field FILE LABEL FIELD_INDEX_WITHIN_VALUE
    awk -v label="$2" -v idx="$3" '
        $1 == label { print $(1 + idx); exit }
    ' "$1"
}

# files:    12                       -> value 1
# asserts:  12 passed, 0 failed      -> value 1 (passed), value 3 (failed)
# guards:   0 registered, 0 proven red -> value 1 (registered), value 3 (proven)
base_files=$(report_field "$BASELINE" "files:" 1)
cur_files=$(report_field "$CURRENT" "files:" 1)
base_asserts=$(report_field "$BASELINE" "asserts:" 1)
cur_asserts=$(report_field "$CURRENT" "asserts:" 1)
base_greg=$(report_field "$BASELINE" "guards:" 1)
cur_greg=$(report_field "$CURRENT" "guards:" 1)
base_gprv=$(report_field "$BASELINE" "guards:" 3)
cur_gprv=$(report_field "$CURRENT" "guards:" 3)

for pair in "files:$base_files:$cur_files" \
            "asserts:$base_asserts:$cur_asserts" \
            "guards-registered:$base_greg:$cur_greg" \
            "guards-proven:$base_gprv:$cur_gprv"; do
    what=${pair%%:*}
    rest=${pair#*:}
    was=${rest%%:*}
    now=${rest#*:}
    case "$was" in
        ''|*[!0-9]*) die "baseline report is unparseable for $what (got '$was')" ;;
    esac
    case "$now" in
        ''|*[!0-9]*) die "current report is unparseable for $what (got '$now')" ;;
    esac
    if [ "$now" -lt "$was" ]; then
        die "$what went DOWN: $was -> $now"
    fi
done

# --- 3. clean working tree --------------------------------------------------
dirty=$(git -C "$REPO_DIR" status --porcelain 2>/dev/null || true)
if [ -n "$dirty" ]; then
    first=$(printf '%s\n' "$dirty" | head -1)
    count=$(printf '%s\n' "$dirty" | grep -c . || true)
    die "working tree not clean ($count entries, e.g. $first)"
fi

# --- 4. no leftover artefacts ----------------------------------------------
# `find -not -path` is portable; -path with a glob is POSIX. .git is excluded
# because packfiles legitimately carry .old-ish names.
leftovers=$(find "$REPO_DIR" -path "$REPO_DIR/.git" -prune -o \
    \( -name '*.new' -o -name '*.old' -o -name 'tmp.*' -o -name '*.tmp' \
       -o -name 'trellis-guard.*' -o -name 'trellis-runall.*' \
       -o -name 'trellis-phasegate.*' \) -print 2>/dev/null | head -5 || true)
if [ -n "$leftovers" ]; then
    first=$(printf '%s\n' "$leftovers" | head -1)
    die "leftover artefact under repo: $first"
fi

printf 'PHASE GATE PASS: '
awk '$1 == "files:" { f=$2 }
     $1 == "asserts:" { a=$2 }
     $1 == "guards:" { g=$2; p=$4 }
     END { printf "%s files, %s asserts, %s/%s guards proven\n", f, a, p, g }' "$CURRENT"
exit 0
