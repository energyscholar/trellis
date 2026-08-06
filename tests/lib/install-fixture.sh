#!/usr/bin/env bash
# tests/lib/install-fixture.sh — build a throwaway Trellis install to run the
# real scripts against.
#
#     . "$(cd "$(dirname "$0")" && pwd)/lib/install-fixture.sh"
#     mk_install "$WORK/main"
#     out=$(tr_rebuild "$WORK/main")
#
# WHY A FIXTURE AND NOT A MOCK
# ----------------------------
# Both defects this fixture exists to catch are defects of the WHOLE pipeline:
# a rebuild that drops a table nothing seeds, and a staleness key that cannot
# see the pipeline change. Neither is visible to a unit test of any single
# function — the first needs a real schema, a real load step and a real atomic
# swap, and the second needs two consecutive runs against the same install. So
# the fixture is a genuine install: the shipped scripts, the shipped schema, a
# real sqlite3 database.
#
# Every function takes the install directory as its first argument, so one test
# file can hold several independent installs — which is what a guard needs,
# since it vandalises one fixture and must not disturb the others.
#
# Portability: bash 3.2 / BSD userland.

_FIXTURE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
FIXTURE_REPO="$(dirname "$_FIXTURE_LIB_DIR")"
FIXTURE_REPO="$(dirname "$FIXTURE_REPO")"
FIXTURE_TEMPLATE="$FIXTURE_REPO/template/scripts"

# mk_install DIR [db_enabled] — a complete install rooted at DIR.
mk_install() {
    local dir="$1" db_enabled="${2:-true}"

    mkdir -p "$dir/memory" "$dir/scripts/db" "$dir/scripts/lib"
    cp "$FIXTURE_TEMPLATE/rebuild-db.sh"      "$dir/scripts/"
    cp "$FIXTURE_TEMPLATE/ingest-memories.sh" "$dir/scripts/"
    cp "$FIXTURE_TEMPLATE/lib/config.sh"      "$dir/scripts/lib/"
    cp "$FIXTURE_TEMPLATE/lib/health-seed.sh" "$dir/scripts/lib/"
    cp "$FIXTURE_TEMPLATE/db/schema.sql"      "$dir/scripts/db/"
    cp "$FIXTURE_TEMPLATE/db/views.sql"       "$dir/scripts/db/"
    chmod +x "$dir/scripts/"*.sh

    printf '%s\n' \
        'version: "0.5.0"' \
        'memory:' \
        '  enabled: true' \
        '  memory_index_cap: 200' \
        '  compression_trigger: 180' \
        'database:' \
        "  enabled: $db_enabled" \
        '  path: trellis.db' \
        '  fts5: true' > "$dir/config.yaml"

    printf '# Memory Index\n\nFile Map: protocol.md corrections.md\n' > "$dir/memory/MEMORY.md"
    printf '# Protocol\n' > "$dir/memory/protocol.md"
    printf '# Corrections\n' > "$dir/memory/corrections.md"
}

# tr_rebuild DIR [args...] — run the install's rebuild-db.sh, echo its output.
# stderr is folded in so a failure is visible in the same string the assertions
# read; the exit status is preserved.
tr_rebuild() {
    local dir="$1"
    shift
    TRELLIS_HOME="$dir" bash "$dir/scripts/rebuild-db.sh" "$@" 2>&1
}

# fixture_db DIR — path to the install's database.
fixture_db() {
    printf '%s\n' "$1/trellis.db"
}

# snapshot_count DIR — rows in health_snapshots, or 0 if there is no database.
snapshot_count() {
    local db="$1/trellis.db"
    [ -f "$db" ] || { printf '0\n'; return 0; }
    sqlite3 "$db" "SELECT COUNT(*) FROM health_snapshots;" 2>/dev/null || printf '0\n'
}

# write_snapshot DIR SESSION DATE [PRESSURE] — what a health writer does:
# INSERT the row into the LIVE database, and append it to the seed so the next
# rebuild can reload it. Phase 3 wires this into memory-sync.sh; here it stands
# in for that writer so the mechanism can be tested on its own.
write_snapshot() {
    local dir="$1" session="$2" date="$3" pressure="${4:-0.50}"
    sqlite3 "$dir/trellis.db" \
        "INSERT INTO health_snapshots (session_number, date, pressure, freshness, coverage, drift, notes)
         VALUES ($session, '$date', $pressure, 0.90, 1.00, 0.10, 'fixture');" 2>/dev/null || true
    seed_snapshot "$dir" "$session" "$date" "$pressure"
}

# seed_snapshot DIR SESSION DATE [PRESSURE] — the seed append ONLY, sourced
# from the install's own copy of the lib so a guard can patch that copy.
seed_snapshot() {
    local dir="$1" session="$2" date="$3" pressure="${4:-0.50}"
    (
        TRELLIS_HOME="$dir"
        export TRELLIS_HOME
        unset TRELLIS
        config="$dir/config.yaml"
        . "$dir/scripts/lib/config.sh"
        . "$dir/scripts/lib/health-seed.sh"
        append_health_seed "$session" "$date" "$pressure" 0.90 1.00 0.10 "fixture"
    ) 2>&1
}
