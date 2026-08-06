#!/usr/bin/env bash
# test-rebuild-db.sh — rebuild-db.sh must not destroy what it cannot rebuild,
# and must notice when the pipeline itself changes.
#
# THE TWO DEFECTS THIS FILE ENCODES (both measured, not theorised)
# ---------------------------------------------------------------
# A. scripts/db/ ships schema.sql and views.sql and nothing else. A rebuild
#    creates a NEW database from those, loads db/data-*.sql over it and mv's it
#    on top of the live one. health_snapshots had no seed and no markdown
#    source, so a snapshot went 1 row -> 0 rows across a rebuild, and 1 -> 0
#    across a plain health-check.sh, which calls rebuild-db.sh --if-stale
#    unattended at session start. v_health_shift needs two rows and could never
#    have them.
#
# B. The staleness key hashed memory/*.md only. Changing db/schema.sql and
#    running --if-stale produced silence and exit 0. Any future schema column,
#    view or parser change would therefore fail to install on an existing
#    install, and any check built on top of it would report zero findings —
#    green — having never been built at all.
#
# H8 and R1 are GUARDS: each reverts its fix inside a throwaway install and
# requires the assertions to go red. An assertion that has only been seen
# passing cannot distinguish "the fix works" from "the assertion is blind".
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

. "$SCRIPT_DIR/lib/guard.sh"
. "$SCRIPT_DIR/lib/install-fixture.sh"

if ! command -v sqlite3 >/dev/null 2>&1; then
    skip_test "sqlite3 absent: rebuild-db.sh cannot be exercised"
    exit 0
fi

WORK=$(mktemp -d "${TMPDIR:-/tmp}/trellis-rebuild.XXXXXXXX")
trap 'rm -rf "$WORK"' EXIT

# --- H8 GUARD: a snapshot survives a full rebuild ---------------------------
register_guard H8 "a health snapshot survives a full rebuild (seed-backed history)"

FIXH="$WORK/h8"
mk_install "$FIXH"

assert_h8() {
    # Self-resetting: prove_guard runs this twice against the same install.
    rm -f "$FIXH/scripts/db/data-health.sql" "$FIXH/trellis.db" "$FIXH/.db-memory-checksum"
    tr_rebuild "$FIXH" >/dev/null 2>&1

    write_snapshot "$FIXH" 41 2026-08-06 0.71 >/dev/null 2>&1
    assert_eq "1" "$(snapshot_count "$FIXH")" "H8 snapshot present before the rebuild"

    tr_rebuild "$FIXH" >/dev/null 2>&1
    assert_eq "1" "$(snapshot_count "$FIXH")" "H8 snapshot survives a full rebuild"
}

# The forbidden implementation is the one that shipped: a writer that puts the
# row in the live database only. It looks correct — the row is there — right up
# until the next rebuild swaps a fresh database over the top of it.
patch_h8() {
    cat >> "$FIXH/scripts/lib/health-seed.sh" <<'NOSEED'
append_health_seed() { return 0; }
NOSEED
}

prove_guard H8 patch_h8 assert_h8 || true

# --- H8b: idempotence on (session, date) ------------------------------------
FIXI="$WORK/h8b"
mk_install "$FIXI"
tr_rebuild "$FIXI" >/dev/null 2>&1

seed_snapshot "$FIXI" 42 2026-08-07 0.60 >/dev/null 2>&1
h8b_second=$(seed_snapshot "$FIXI" 42 2026-08-07 0.61 2>&1)
tr_rebuild "$FIXI" >/dev/null 2>&1

assert_eq "1" "$(snapshot_count "$FIXI")" \
    "H8b the same (session,date) appended twice is ONE row after a rebuild" || true
assert_contains "$h8b_second" "replaced" \
    "H8b the second append says it replaced the first, rather than saying nothing" || true

# The other half of idempotence: deduplication must not collapse DIFFERENT
# snapshots. v_health_shift self-joins two rows; a seed that only ever holds one
# is as dead as a seed that holds none.
seed_snapshot "$FIXI" 43 2026-08-08 0.65 >/dev/null 2>&1
tr_rebuild "$FIXI" >/dev/null 2>&1
assert_eq "2" "$(snapshot_count "$FIXI")" \
    "H8b a different session is a second row, not a replacement" || true

# --- R1 GUARD: a pipeline change forces a rebuild ---------------------------
register_guard R1 "a db/schema.sql change alone makes --if-stale rebuild"

FIXR="$WORK/r1"
mk_install "$FIXR"

assert_r1() {
    # Stamp the install fresh, then change ONE pipeline file and nothing else.
    # The change has to be to the file's CONTENT: the key is a content hash, so
    # a bare `touch` is not a pipeline change and must not be treated as one.
    tr_rebuild "$FIXR" >/dev/null 2>&1
    printf -- '-- pipeline change probe\n' >> "$FIXR/scripts/db/schema.sql"

    local out
    out=$(tr_rebuild "$FIXR" --if-stale 2>&1)
    assert_contains "$out" "Rebuild complete" "R1 schema.sql change alone triggers a rebuild"
    assert_not_contains "$out" "no rebuild" "R1 --if-stale did not declare itself fresh"
}

# The forbidden implementation: the memory-only staleness key. Only the CALL
# SITES are rewritten — renaming the definition would merely alias the fix back
# into place and the guard would stay green while proving nothing.
patch_r1() {
    awk '
        /^compute_staleness_key\(\)/ { print; next }
        { gsub(/compute_staleness_key/, "compute_memory_checksum"); print }
    ' "$FIXR/scripts/rebuild-db.sh" > "$FIXR/scripts/rebuild-db.legacy"
    mv "$FIXR/scripts/rebuild-db.legacy" "$FIXR/scripts/rebuild-db.sh"
    chmod +x "$FIXR/scripts/rebuild-db.sh"
}

prove_guard R1 patch_r1 assert_r1 || true

# --- R2: deciding NOT to rebuild is still a decision, and it says so --------
FIX2="$WORK/r2"
mk_install "$FIX2"
tr_rebuild "$FIX2" >/dev/null 2>&1

r2_out=$(tr_rebuild "$FIX2" --if-stale 2>&1)
r2_rc=$?

assert_eq "0" "$r2_rc" "R2 --if-stale exits 0 when nothing changed" || true
assert_contains "$r2_out" "no rebuild" \
    "R2 --if-stale states that it is not rebuilding" || true
assert_contains "$r2_out" "fresh" \
    "R2 --if-stale gives the reason (fresh: memory + pipeline unchanged)" || true
assert_not_contains "$r2_out" "Rebuild complete" \
    "R2 an unchanged install is not rebuilt" || true

# --- R3: database disabled — a clean no-op that says why --------------------
FIX3="$WORK/r3"
mk_install "$FIX3" false

r3_out=$(seed_snapshot "$FIX3" 44 2026-08-06 0.50 2>&1)
r3_rc=$?

assert_eq "0" "$r3_rc" "R3 seed-append exits 0 with the database disabled" || true
assert_contains "$r3_out" "database.enabled" \
    "R3 the skipped seed-append names the config key that skipped it" || true
assert_eq "absent" \
    "$([ -f "$FIX3/scripts/db/data-health.sql" ] && echo present || echo absent)" \
    "R3 no seed file is written when the database is off" || true

guard_summary
