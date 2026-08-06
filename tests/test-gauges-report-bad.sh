#!/usr/bin/env bash
# test-gauges-report-bad.sh — one assertion per gauge: break the thing the
# gauge watches, and require the gauge to SAY SO.
#
# This replaces a manual drill checklist that was performed by hand, at the end
# of a release, by the person who wrote the gauges. A gauge with no assertion
# here is not wired — it is decorated. The file grows one Gn per phase; each
# phase adds the drills for the gauges it created.
#
#   G9  write a snapshot, force a full rebuild   the row survives
#   G11 change db/schema.sql alone               --if-stale rebuilds
#
# Guards for these two live in tests/test-rebuild-db.sh (H8, R1), which also
# proves each one red. This file is the drill: the shortest path from "break
# it" to "the gauge reported it".
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

. "$SCRIPT_DIR/lib/guard.sh"
. "$SCRIPT_DIR/lib/install-fixture.sh"

if ! command -v sqlite3 >/dev/null 2>&1; then
    skip_test "sqlite3 absent: rebuild-db.sh cannot be exercised"
    exit 0
fi

WORK=$(mktemp -d "${TMPDIR:-/tmp}/trellis-gauges.XXXXXXXX")
trap 'rm -rf "$WORK"' EXIT

# --- G9: write a snapshot, force a full rebuild, the row survives -----------
G9="$WORK/g9"
mk_install "$G9"
tr_rebuild "$G9" >/dev/null 2>&1

write_snapshot "$G9" 231 2026-08-06 0.71 >/dev/null 2>&1
assert_eq "1" "$(snapshot_count "$G9")" "G9 snapshot is in the database before the rebuild" || true

tr_rebuild "$G9" >/dev/null 2>&1
assert_eq "1" "$(snapshot_count "$G9")" "G9 snapshot survives a forced full rebuild" || true

# --- G11: change db/schema.sql alone, --if-stale rebuilds -------------------
G11="$WORK/g11"
mk_install "$G11"
tr_rebuild "$G11" >/dev/null 2>&1

# Content, not mtime: the staleness key is a content hash, so a bare `touch`
# is correctly a no-change and asserting on it would test nothing.
printf -- '-- schema change: a new column would land here\n' >> "$G11/scripts/db/schema.sql"

g11_out=$(tr_rebuild "$G11" --if-stale 2>&1)
assert_contains "$g11_out" "Rebuild complete" \
    "G11 a schema.sql-only change makes --if-stale rebuild" || true
assert_contains "$g11_out" "pipeline" \
    "G11 the rebuild names the pipeline as the reason" || true

guard_summary
