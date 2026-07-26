#!/usr/bin/env bash
# test-acs-session-formats.sh — ACS reads pre-v0.5 numeric session ids.
#
# Installations created before v0.5 wrote bare numeric rows (| 17 |); v0.5
# writes | S22 |. A parser that accepts only the S form silently discards the
# whole pre-update history, so every consumer of session-log.md must read both.
# Covers: numeric-only, S-only, mixed, and the first/last identifiers ACS
# reports for its window.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

errors=0

fail() {
    echo "FAIL: $1" >&2
    errors=$((errors + 1))
}

# Build a Trellis home whose session log holds $2..$n rows verbatim.
make_home() {
    local home="$TMPDIR/$1"; shift
    rm -rf "$home"
    cp -r "$REPO/template/" "$home/"
    {
        echo "| Session | Date | Domain | Memory | Structure | Ethics |"
        echo "|---------|------|--------|--------|-----------|--------|"
        printf '%s\n' "$@"
    } > "$home/memory/session-log.md"
    echo "$home"
}

# A row with enough event content that ACS has something to compute over.
row() {
    printf '| %s | 2026-06-%02d | general | correction, save | plan, follow | l0 |' "$1" "$2"
}

numeric_rows=()
s_rows=()
mixed_rows=()
for i in $(seq 1 12); do
    numeric_rows+=("$(row "$i" "$i")")
    s_rows+=("$(row "S$i" "$i")")
done
# Mixed: legacy numeric history followed by post-update S rows.
for i in $(seq 1 6); do mixed_rows+=("$(row "$i" "$i")"); done
for i in $(seq 7 12); do mixed_rows+=("$(row "S$i" "$i")"); done

# --- acs-check.sh counts rows in every format ---
for case in numeric s mixed; do
    case "$case" in
        numeric) rows=("${numeric_rows[@]}"); first="1";  last="12"  ;;
        s)       rows=("${s_rows[@]}");       first="S1"; last="S12" ;;
        mixed)   rows=("${mixed_rows[@]}");   first="1";  last="S12" ;;
    esac

    home=$(make_home "acs-$case" "${rows[@]}")
    out=$(TRELLIS_HOME="$home" bash "$home/scripts/acs-check.sh" 2>&1)

    if echo "$out" | grep -q 'insufficient data'; then
        fail "acs-check.sh ignored 12 $case session rows:
$out"
        continue
    fi

    # The window header names the first and last identifier it read.
    if ! echo "$out" | grep -qF "$first"; then
        fail "acs-check.sh ($case) did not report first session '$first':
$out"
    fi
    if ! echo "$out" | grep -qF "$last"; then
        fail "acs-check.sh ($case) did not report last session '$last':
$out"
    fi
done

# --- Session counts agree across every consumer of session-log.md ---
for case in numeric s mixed; do
    case "$case" in
        numeric) rows=("${numeric_rows[@]}") ;;
        s)       rows=("${s_rows[@]}") ;;
        mixed)   rows=("${mixed_rows[@]}") ;;
    esac
    home=$(make_home "count-$case" "${rows[@]}")

    got=$(grep -cE '^\| S?[0-9]' "$home/memory/session-log.md")
    [ "$got" -eq 12 ] || fail "grep matcher counted $got of 12 $case rows"

    prop=$(TRELLIS_HOME="$home" bash "$home/scripts/proprioceptive-check.sh" 2>&1 || true)
    prop_count=$(echo "$prop" | sed -n 's/^Session:[[:space:]]*\([0-9][0-9]*\) sessions logged.*/\1/p')
    [ "$prop_count" = "12" ] || fail "proprioceptive-check.sh counted '${prop_count:-none}' of 12 $case sessions:
$prop"

    # Provenance is parsed from the same rows; unread rows degrade to "no data".
    if echo "$prop" | grep -q 'no data yet'; then
        fail "proprioceptive-check.sh read no provenance from 12 $case rows:
$prop"
    fi
done

# --- A log with no data rows still reads as empty, not as a false count ---
home=$(make_home "empty")
out=$(TRELLIS_HOME="$home" bash "$home/scripts/acs-check.sh" 2>&1)
echo "$out" | grep -q 'insufficient data' || {
    fail "acs-check.sh did not report insufficient data for an empty log:
$out"
}

# --- Separator and header lines are never counted as sessions ---
got=$(grep -cE '^\| S?[0-9]' <<'EOF' || true
| Session | Date | Domain | Memory | Structure | Ethics |
|---------|------|--------|--------|-----------|--------|
| S1 | 2026-06-01 | general | save | plan | l0 |
| 2 | 2026-06-02 | general | save | plan | l0 |
EOF
)
[ "$got" -eq 2 ] || fail "matcher counted $got rows; header/separator must not match"

if [ "$errors" -gt 0 ]; then
    echo "test-acs-session-formats.sh: $errors failure(s)" >&2
    exit 1
fi
echo "test-acs-session-formats.sh: OK"
