#!/usr/bin/env bash
# tests/run-all.sh — run every tests/test-*.sh and account for what happened.
#
# The old runner counted FILES and threw the output away. Both were bugs:
# a file that silently lost half its assertions still printed PASS, and a test
# announcing "SKIP: sqlite3 absent" wrote that announcement to /dev/null. This
# runner counts ASSERTIONS, surfaces every skip, and refuses to let a declared
# guard go unproven.
#
# Test files talk to the runner through three machine-readable line formats,
# all emitted by tests/lib/guard.sh:
#
#   ASSERTS <n_passed> <n_failed>     the file's assertion tally
#   GUARD <id> proven|UNPROVEN        one forbidden-implementation guard
#   SKIP: <reason>                    something was not exercised
#
# A file that emits none of these still works and counts as one assertion,
# which is what keeps the pre-existing tests passing unmodified.
#
# Usage:
#   bash tests/run-all.sh              human-readable PASS/FAIL + N/M passed
#   bash tests/run-all.sh --report     machine/report form (see REPORT below)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
ALLOWED_SKIPS="$SCRIPT_DIR/allowed-skips.txt"

MODE="human"
if [ "${1:-}" = "--report" ]; then
    MODE="report"
elif [ "$#" -gt 0 ]; then
    echo "usage: $0 [--report]" >&2
    exit 2
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "Missing test dependency: python3" >&2
    exit 2
fi

if ! python3 -c 'import yaml' >/dev/null 2>&1; then
    # Plain pip install is refused on externally-managed interpreters (PEP 668:
    # Debian 12+, Ubuntu 23.04+, Homebrew Python), which is exactly where a new
    # contributor lands first. Offer a route that works there too.
    echo "Missing test dependency: PyYAML" >&2
    echo "" >&2
    echo "Install it one of these ways:" >&2
    echo "  python3 -m pip install -r \"$REPO_DIR/requirements-test.txt\"" >&2
    echo "  # if that reports 'externally-managed-environment' (PEP 668):" >&2
    echo "  sudo apt install python3-yaml          # Debian/Ubuntu system package" >&2
    echo "  brew install libyaml && pip3 install --user PyYAML   # macOS/Homebrew" >&2
    echo "  # or use a virtualenv:" >&2
    echo "  python3 -m venv .venv && .venv/bin/pip install -r \"$REPO_DIR/requirements-test.txt\"" >&2
    echo "  PATH=\"\$PWD/.venv/bin:\$PATH\" bash tests/run-all.sh" >&2
    exit 2
fi

WORK=$(mktemp -d "${TMPDIR:-/tmp}/trellis-runall.XXXXXXXX")
trap 'rm -rf "$WORK"' EXIT

passed=0
failed=0
total=0
asserts_pass=0
asserts_fail=0
guards_registered=0
guards_proven=0
unproven=""
skips=""          # newline-delimited "<test-file>|<reason>"
undeclared=""     # newline-delimited "<test-file>|<reason>"

# A reason is declared if it appears verbatim on a non-comment line of
# allowed-skips.txt. Literal match (grep -Fx): a skip register that accepts
# patterns is a skip register that accepts anything.
skip_declared() {
    local reason="$1"
    [ -f "$ALLOWED_SKIPS" ] || return 1
    grep -v '^[[:space:]]*#' "$ALLOWED_SKIPS" 2>/dev/null \
        | grep -v '^[[:space:]]*$' \
        | grep -Fxq "$reason"
}

for test in "$SCRIPT_DIR"/test-*.sh; do
    [ -f "$test" ] || continue
    name=$(basename "$test")
    total=$((total + 1))
    out="$WORK/$name.out"

    rc=0
    bash "$test" >"$out" 2>&1 || rc=$?

    # --- tally lines -------------------------------------------------------
    file_pass=0
    file_fail=0
    saw_tally=0
    while IFS= read -r line; do
        case "$line" in
            "ASSERTS "*)
                set -- $line
                if [ "$#" -eq 3 ]; then
                    saw_tally=1
                    file_pass=$((file_pass + $2))
                    file_fail=$((file_fail + $3))
                fi
                ;;
            "GUARD "*)
                set -- $line
                if [ "$#" -eq 3 ]; then
                    guards_registered=$((guards_registered + 1))
                    if [ "$3" = "proven" ]; then
                        guards_proven=$((guards_proven + 1))
                    else
                        unproven="${unproven}${2}
"
                    fi
                fi
                ;;
            "SKIP:"*)
                reason=${line#SKIP:}
                # strip one leading space without sed/expr
                reason=${reason# }
                skips="${skips}${name}|${reason}
"
                if ! skip_declared "$reason"; then
                    undeclared="${undeclared}${name}|${reason}
"
                fi
                ;;
        esac
    done < "$out"

    if [ "$saw_tally" -eq 0 ]; then
        # Legacy test: no tally line. The file itself is the assertion.
        if [ "$rc" -eq 0 ]; then
            file_pass=1
        else
            file_fail=1
        fi
    fi
    asserts_pass=$((asserts_pass + file_pass))
    asserts_fail=$((asserts_fail + file_fail))

    if [ "$rc" -eq 0 ]; then
        passed=$((passed + 1))
        verdict="PASS"
    else
        failed=$((failed + 1))
        verdict="FAIL"
    fi

    if [ "$MODE" = "human" ]; then
        echo "  $verdict  $name"
        # Surface skips at the point they happened; a skip nobody sees is
        # indistinguishable from a test that ran.
        while IFS= read -r line; do
            case "$line" in
                "SKIP:"*) echo "        $line" ;;
            esac
        done < "$out"
        if [ "$rc" -ne 0 ]; then
            while IFS= read -r line; do
                echo "        $line"
            done < "$out"
        fi
    fi
done

# --- report -----------------------------------------------------------------
if [ "$MODE" = "report" ]; then
    commit=$(git -C "$REPO_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")
    if [ -n "$unproven" ]; then
        # newline-delimited -> comma-separated, without GNU-only tricks
        unproven_list=$(printf '%s' "$unproven" | tr '\n' ' ')
        unproven_list=$(printf '%s' "$unproven_list" | sed 's/[[:space:]]*$//; s/ /, /g')
    else
        # Em dash as the empty marker. It is only ever a quoted VALUE here —
        # bash 3.2 folds multi-byte bytes into an UNBRACED $var name, which is
        # a different construct and not one this file uses.
        unproven_list="—"
    fi

    printf 'TRELLIS TEST REPORT\n'
    printf 'commit:   %s\n' "$commit"
    printf 'files:    %s\n' "$total"
    printf 'asserts:  %s passed, %s failed\n' "$asserts_pass" "$asserts_fail"
    printf 'guards:   %s registered, %s proven red\n' "$guards_registered" "$guards_proven"
    printf 'unproven: %s\n' "$unproven_list"
    printf 'platform: %s\n' "$(uname -s)"

    if [ -n "$skips" ]; then
        printf '\n'
        while IFS= read -r entry; do
            [ -n "$entry" ] || continue
            printf 'SKIP: %s (%s)\n' "${entry#*|}" "${entry%%|*}"
        done <<EOF
$skips
EOF
    fi

    rc=0
    if [ "$asserts_fail" -gt 0 ]; then
        printf 'GATE FAIL: %s assertion(s) failed\n' "$asserts_fail" >&2
        rc=1
    fi
    if [ "$guards_registered" -ne "$guards_proven" ]; then
        printf 'GATE FAIL: %s guard(s) registered but %s proven\n' \
            "$guards_registered" "$guards_proven" >&2
        rc=1
    fi
    if [ -n "$unproven" ]; then
        printf 'GATE FAIL: unproven guard(s): %s\n' "$unproven_list" >&2
        rc=1
    fi
    if [ -n "$undeclared" ]; then
        while IFS= read -r entry; do
            [ -n "$entry" ] || continue
            printf 'GATE FAIL: undeclared skip in %s: %s\n' \
                "${entry%%|*}" "${entry#*|}" >&2
        done <<EOF
$undeclared
EOF
        rc=1
    fi
    if [ "$failed" -gt 0 ]; then
        printf 'GATE FAIL: %s test file(s) failed\n' "$failed" >&2
        rc=1
    fi
    exit "$rc"
fi

echo ""
echo "asserts: $asserts_pass passed, $asserts_fail failed"
echo "$passed/$total passed"
if [ -n "$unproven" ]; then
    printf 'UNPROVEN GUARDS: %s\n' "$(printf '%s' "$unproven" | tr '\n' ' ')" >&2
fi
if [ -n "$undeclared" ]; then
    while IFS= read -r entry; do
        [ -n "$entry" ] || continue
        printf 'UNDECLARED SKIP in %s: %s\n' "${entry%%|*}" "${entry#*|}" >&2
    done <<EOF
$undeclared
EOF
fi
if [ "$failed" -gt 0 ] || [ "$asserts_fail" -gt 0 ] || [ -n "$unproven" ] || [ -n "$undeclared" ]; then
    exit 1
fi
exit 0
