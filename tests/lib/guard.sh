#!/usr/bin/env bash
# tests/lib/guard.sh — forbidden-implementation guards + counted assertions.
#
# Source this from a test file:
#
#     . "$(cd "$(dirname "$0")" && pwd)/lib/guard.sh"
#     ... asserts ...
#     guard_summary      # MUST be the last statement; it exits.
#
# WHY THIS EXISTS
# ---------------
# A check that has only ever been observed passing is untested. It may be
# green because the fix works, or green because the check cannot see the bug
# at all. The only way to tell them apart is to break the fix on purpose and
# watch the check go red.
#
#   register_guard ID "description"        declare that a guard exists
#   prove_guard   ID patch_fn assert_fn    run assert_fn twice: once against
#                                          the fixture carrying the fix (must
#                                          PASS), once after patch_fn has
#                                          reverted the fix in that same
#                                          throwaway fixture (must FAIL)
#   guard_summary                          emit machine-readable results, exit
#
# A registered-but-unproven guard is a TEST FAILURE, not a warning. Declaring
# a guard and never proving it is the exact bypass this mechanism forbids.
#
# MACHINE-READABLE OUTPUT (parsed by run-all.sh)
#   GUARD <id> proven
#   GUARD <id> UNPROVEN
#   ASSERTS <n_passed> <n_failed>
#
# Portability: bash 3.2 / BSD userland. No associative arrays, no `local -n`,
# no GNU-only utilities. Newline-delimited strings stand in for maps.

# --- state ------------------------------------------------------------------
# Every variable is initialised so `set -u` in the sourcing test is safe.
_ASSERT_PASS=0
_ASSERT_FAIL=0
_GUARD_IDS=""        # newline-delimited ids, registration order
_GUARD_DESCS=""      # newline-delimited "id<TAB>description"
_GUARD_PROVEN=""     # newline-delimited ids that went green-then-red
_GUARD_PROBE=0       # 1 while running an assert_fn under prove_guard
_GUARD_PROBE_FILE="" # probe failure sink; non-empty file means "went red"
_GUARD_SUMMARY_DONE=0

# --- internals --------------------------------------------------------------

# _guard_has LIST ID — is ID one of LIST's newline-delimited entries?
_guard_has() {
    case "
$1
" in
        *"
$2
"*) return 0 ;;
    esac
    return 1
}

# _assert_ok MESSAGE — record one passing assertion.
_assert_ok() {
    if [ "$_GUARD_PROBE" -eq 1 ]; then
        return 0
    fi
    _ASSERT_PASS=$((_ASSERT_PASS + 1))
    return 0
}

# _assert_bad MESSAGE [detail...] — record one failing assertion.
# Inside a probe this is silent and merely marks the probe red, because a
# probe's second run is SUPPOSED to fail; counting it would corrupt the tally.
_assert_bad() {
    if [ "$_GUARD_PROBE" -eq 1 ]; then
        printf 'x' >> "$_GUARD_PROBE_FILE"
        return 1
    fi
    _ASSERT_FAIL=$((_ASSERT_FAIL + 1))
    printf 'ASSERT FAIL: %s\n' "$1" >&2
    shift
    while [ "$#" -gt 0 ]; do
        printf '  %s\n' "$1" >&2
        shift
    done
    return 1
}

# --- assertion helpers ------------------------------------------------------
# Each increments the tally exactly once, so assertion counting needs no
# bookkeeping in the test itself. All return non-zero on failure; under
# `set -e` a bare call therefore aborts the test, which is the usual want.
# Use `assert_eq ... || true` to keep going and still record the failure.

# assert_eq EXPECTED ACTUAL [message]
assert_eq() {
    local expected="$1" actual="$2" msg="${3:-values differ}"
    if [ "$expected" = "$actual" ]; then
        _assert_ok "$msg"
    else
        _assert_bad "$msg" "expected: $expected" "actual:   $actual"
    fi
}

# assert_contains HAYSTACK NEEDLE [message] — literal substring test.
assert_contains() {
    local haystack="$1" needle="$2" msg="${3:-substring not found}"
    case "$haystack" in
        *"$needle"*) _assert_ok "$msg" ;;
        *) _assert_bad "$msg" "looking for: $needle" "in: $haystack" ;;
    esac
}

# assert_not_contains HAYSTACK NEEDLE [message]
assert_not_contains() {
    local haystack="$1" needle="$2" msg="${3:-unexpected substring present}"
    case "$haystack" in
        *"$needle"*) _assert_bad "$msg" "found: $needle" "in: $haystack" ;;
        *) _assert_ok "$msg" ;;
    esac
}

# assert_exit EXPECTED_CODE command [args...]
assert_exit() {
    local expected="$1"
    shift
    local rc=0
    "$@" >/dev/null 2>&1 || rc=$?
    if [ "$rc" -eq "$expected" ]; then
        _assert_ok "exit $expected from $1"
    else
        _assert_bad "exit status from $1" "expected: $expected" "actual:   $rc"
    fi
}

# assert_matches STRING ERE [message] — POSIX ERE, never grep -P.
assert_matches() {
    local subject="$1" pattern="$2" msg="${3:-pattern did not match}"
    if printf '%s\n' "$subject" | grep -Eq "$pattern"; then
        _assert_ok "$msg"
    else
        _assert_bad "$msg" "pattern: $pattern" "subject: $subject"
    fi
}

# assert_file FILE [message]
assert_file() {
    local path="$1" msg="${2:-file missing: $1}"
    if [ -f "$path" ]; then
        _assert_ok "$msg"
    else
        _assert_bad "$msg" "no such file: $path"
    fi
}

# --- guards -----------------------------------------------------------------

# register_guard ID "description"
register_guard() {
    local id="$1" desc="${2:-}"
    if [ -z "$id" ]; then
        printf 'register_guard: empty id\n' >&2
        return 2
    fi
    if _guard_has "$_GUARD_IDS" "$id"; then
        printf 'register_guard: duplicate id: %s\n' "$id" >&2
        return 2
    fi
    _GUARD_IDS="${_GUARD_IDS}${id}
"
    _GUARD_DESCS="${_GUARD_DESCS}${id}	${desc}
"
}

# _guard_run FN — run FN in probe mode inside a subshell. Returns 0 if the
# assertions held, 1 if any failed (or FN exited non-zero, or FN called
# `exit 1` outright, which is this repo's older assertion style).
_guard_run() {
    local fn="$1" sink="$2" rc=0
    : > "$sink"
    (
        set +e
        _GUARD_PROBE=1
        _GUARD_PROBE_FILE="$sink"
        "$fn"
        exit $?
    ) >/dev/null 2>&1 || rc=$?
    if [ "$rc" -ne 0 ]; then
        return 1
    fi
    if [ -s "$sink" ]; then
        return 1
    fi
    return 0
}

# prove_guard ID patch_fn assert_fn
#
# assert_fn must be green against the fixture as-built and red once patch_fn
# has reverted the fix. Both outcomes are required; either one missing leaves
# the guard UNPROVEN, which fails the test.
prove_guard() {
    local id="$1" patch_fn="$2" assert_fn="$3"
    local sink green_rc=0 red_rc=0 patch_rc=0

    if ! _guard_has "$_GUARD_IDS" "$id"; then
        printf 'prove_guard: %s was never registered\n' "$id" >&2
        _ASSERT_FAIL=$((_ASSERT_FAIL + 1))
        return 1
    fi

    sink=$(mktemp "${TMPDIR:-/tmp}/trellis-guard.XXXXXXXX")

    # 1. The fix is present: the assertion must hold.
    _guard_run "$assert_fn" "$sink" || green_rc=1

    # 2. Revert the fix in the throwaway fixture.
    "$patch_fn" >/dev/null 2>&1 || patch_rc=$?

    # 3. The same assertion must now fail. If it still passes, the assertion
    #    is not actually watching the thing the guard claims to protect.
    _guard_run "$assert_fn" "$sink" || red_rc=1

    rm -f "$sink"

    if [ "$patch_rc" -ne 0 ]; then
        printf 'GUARD %s: patch_fn (%s) exited %s\n' "$id" "$patch_fn" "$patch_rc" >&2
        _ASSERT_FAIL=$((_ASSERT_FAIL + 1))
        return 1
    fi
    if [ "$green_rc" -ne 0 ]; then
        printf 'GUARD %s: %s failed WITH the fix in place\n' "$id" "$assert_fn" >&2
        _ASSERT_FAIL=$((_ASSERT_FAIL + 1))
        return 1
    fi
    if [ "$red_rc" -eq 0 ]; then
        printf 'GUARD %s: %s still passed after %s reverted the fix — the check does not test what it claims\n' \
            "$id" "$assert_fn" "$patch_fn" >&2
        _ASSERT_FAIL=$((_ASSERT_FAIL + 1))
        return 1
    fi

    _GUARD_PROVEN="${_GUARD_PROVEN}${id}
"
    # A proven guard is worth exactly one passing assertion: it demonstrated
    # both that the fix holds and that its absence is detectable.
    _ASSERT_PASS=$((_ASSERT_PASS + 1))
    return 0
}

# guard_summary — emit GUARD/ASSERTS lines and exit with the verdict.
# Terminal by design: nothing should run after the tally is published.
guard_summary() {
    local id status bad=0

    if [ "$_GUARD_SUMMARY_DONE" -eq 1 ]; then
        return 0
    fi
    _GUARD_SUMMARY_DONE=1

    # `printf '%s' | while read` keeps bash 3.2 happy and preserves order.
    while IFS= read -r id; do
        [ -n "$id" ] || continue
        if _guard_has "$_GUARD_PROVEN" "$id"; then
            status="proven"
        else
            status="UNPROVEN"
        fi
        printf 'GUARD %s %s\n' "$id" "$status"
    done <<EOF
$_GUARD_IDS
EOF

    while IFS= read -r id; do
        [ -n "$id" ] || continue
        _guard_has "$_GUARD_PROVEN" "$id" || bad=1
    done <<EOF
$_GUARD_IDS
EOF

    printf 'ASSERTS %s %s\n' "$_ASSERT_PASS" "$_ASSERT_FAIL"

    if [ "$_ASSERT_FAIL" -gt 0 ] || [ "$bad" -ne 0 ]; then
        exit 1
    fi
    exit 0
}

# skip_test REASON — the ONLY sanctioned way to skip. It goes to stdout so
# run-all.sh surfaces it; a skip nobody sees is the failure class this repo
# exists to fix. Every reason must be listed in tests/allowed-skips.txt.
skip_test() {
    printf 'SKIP: %s\n' "$1"
}
