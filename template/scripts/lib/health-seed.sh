#!/usr/bin/env bash
# lib/health-seed.sh — health history that survives a rebuild. Source it; do
# not execute it.
#
#     SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
#     . "$SCRIPT_DIR/lib/health-seed.sh"
#     append_health_seed 231 2026-08-06 0.71 0.93 1.00 0.40 "session close"
#
# WHY THIS FILE EXISTS
# --------------------
# scripts/db/ ships schema.sql and views.sql and nothing else. rebuild-db.sh
# builds a NEW database from those two files, loads db/data-*.sql over it, and
# mv's the result on top of the live database. health_snapshots has no seed, no
# markdown source and no preservation step, so a rebuild does not merely "lose"
# health history — it structurally cannot carry it. Measured on a scratch
# install:
#
#     write a snapshot, then rebuild-db.sh:   1 row -> 0 rows
#     write a snapshot, then health-check.sh: 1 row -> 0 rows
#
# The second line is the one that matters. health-check.sh calls
# rebuild-db.sh --if-stale unattended at session start, so the history was
# being erased by the very check that reads it. v_health_shift self-joins
# health_snapshots to its own previous row; against a table that empties itself
# every session it can never return a row at all, and a gauge that can never
# fire looks exactly like a gauge that has nothing to report.
#
# The fix is to give the table a seed, like every other table has. A snapshot
# is appended here as SQL, and rebuild-db.sh's existing db/data-*.sql glob
# reloads it. History then survives a rebuild by the same mechanism that makes
# feedback and projects survive one.
#
# CONTRACT
#   append_health_seed SESSION DATE PRESSURE FRESHNESS COVERAGE DRIFT [NOTES]
#     Appends one snapshot to $TRELLIS/scripts/db/data-health.sql, creating the
#     file if it does not exist. The metric arguments may be empty, which is
#     written as NULL.
#
#     IDEMPOTENT ON (SESSION, DATE): a second call with the same key REPLACES
#     the first entry rather than adding a second one, so a rebuild yields one
#     row per (session, date) no matter how often the writer ran.
#
#     Returns 0 and SAYS WHY when it decides not to write (database disabled,
#     no sqlite3 to load the seed). Returns non-zero only for bad arguments.
#     Every outcome prints exactly one line: an append that quietly did nothing
#     is indistinguishable from one that worked, and that ambiguity is the
#     failure class this whole file exists to remove.
#
# Portability: POSIX awk/grep only. bash 3.2 and BSD userland. No sed -i, no
# md5sum, no realpath — tests/test-portability.sh enforces it.

# The config reader is a hard dependency: whether to write at all is a config
# question (database.enabled), and reading it with a bare grep is the bug
# lib/config.sh was written to kill.
if ! command -v get_config >/dev/null 2>&1; then
    _HEALTH_SEED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
    # shellcheck source=./config.sh
    . "$_HEALTH_SEED_DIR/config.sh"
fi

# _health_seed_home — same resolution order as every other script.
_health_seed_home() {
    if [ -n "${TRELLIS:-}" ]; then
        printf '%s\n' "$TRELLIS"
    elif [ -n "${TRELLIS_HOME:-}" ]; then
        printf '%s\n' "$TRELLIS_HOME"
    elif [ -f "$HOME/.config/trellis/home" ]; then
        cat "$HOME/.config/trellis/home"
    else
        printf '%s\n' "$HOME/.trellis"
    fi
}

# health_seed_path — the file rebuild-db.sh's data-*.sql glob picks up.
health_seed_path() {
    printf '%s\n' "$(_health_seed_home)/scripts/db/data-health.sql"
}

# _health_seed_num VALUE — a SQL numeric literal, or NULL for an empty value.
# Anything that is not a number is rejected rather than interpolated: this text
# is executed by sqlite3 during the next rebuild.
_health_seed_num() {
    case "${1:-}" in
        "") printf 'NULL\n' ;;
        *[!0-9.+-]*) return 1 ;;
        *) printf '%s\n' "$1" ;;
    esac
}

# _health_seed_str VALUE — a quoted SQL string literal with ' doubled.
_health_seed_str() {
    local v="${1:-}"
    v=$(printf '%s' "$v" | awk '{ gsub(/'"'"'/, "'"'"''"'"'"); printf "%s", $0 }')
    printf "'%s'\n" "$v"
}

# append_health_seed SESSION DATE PRESSURE FRESHNESS COVERAGE DRIFT [NOTES]
append_health_seed() {
    local session="${1:-}" date="${2:-}" pressure="${3:-}" freshness="${4:-}"
    local coverage="${5:-}" drift="${6:-}" notes="${7:-}"
    local trellis seed key tmp db_enabled action
    local p_sql f_sql c_sql d_sql

    case "$session" in
        ''|*[!0-9]*)
            echo "health-seed: refusing to write — session number must be an integer, got '$session'" >&2
            return 2
            ;;
    esac
    if [ -z "$date" ]; then
        echo "health-seed: refusing to write — date is empty" >&2
        return 2
    fi

    trellis="$(_health_seed_home)"

    # database.enabled, resolved within its own section. The bare key `enabled`
    # resolves to memory.enabled, which is a different setting entirely.
    db_enabled=$(config="${config:-$trellis/config.yaml}"; get_config "database.enabled" "true")
    if [ "$db_enabled" != "true" ]; then
        echo "health-seed: skipped — database.enabled is false in $trellis/config.yaml (flat-file mode keeps no snapshot history)"
        return 0
    fi

    if ! command -v sqlite3 >/dev/null 2>&1; then
        echo "health-seed: skipped — sqlite3 is not installed, so nothing would ever load the seed (install sqlite3, or set database.enabled: false)"
        return 0
    fi

    p_sql=$(_health_seed_num "$pressure") || {
        echo "health-seed: refusing to write — pressure is not numeric: '$pressure'" >&2; return 2; }
    f_sql=$(_health_seed_num "$freshness") || {
        echo "health-seed: refusing to write — freshness is not numeric: '$freshness'" >&2; return 2; }
    c_sql=$(_health_seed_num "$coverage") || {
        echo "health-seed: refusing to write — coverage is not numeric: '$coverage'" >&2; return 2; }
    d_sql=$(_health_seed_num "$drift") || {
        echo "health-seed: refusing to write — drift is not numeric: '$drift'" >&2; return 2; }

    seed="$trellis/scripts/db/data-health.sql"
    key="${session}|${date}"
    action="recorded"

    if [ ! -d "$trellis/scripts/db" ]; then
        echo "health-seed: skipped — $trellis/scripts/db does not exist (is this a Trellis install?)"
        return 0
    fi

    if [ ! -f "$seed" ]; then
        {
            echo "-- data-health.sql — health snapshot history."
            echo "-- Written by scripts/lib/health-seed.sh, reloaded by rebuild-db.sh."
            echo "--"
            echo "-- health_snapshots has no markdown source, so this file IS the history."
            echo "-- Without it every rebuild starts the table empty and v_health_shift,"
            echo "-- which needs two rows, can never return one. Keep it in version control."
            echo "--"
            echo "-- One block per (session, date), delimited by -- >>> / -- <<< marker"
            echo "-- comments. A rewrite of an existing key replaces its block in place,"
            echo "-- so the file holds exactly one entry per snapshot."
            echo ""
        } > "$seed"
    fi

    # Idempotence on (session, date): drop any existing block for this key
    # before appending the new one. Filter-and-move, because BSD sed -i needs a
    # suffix argument and the portable form is not to use it at all.
    # -e is load bearing: the marker starts with "--", and grep reads a leading
    # "--…" argument as an option, fails, and (behind 2>/dev/null) would leave
    # the deduplication silently never running.
    if grep -Fxq -e "-- >>> health-seed ${key}" "$seed" 2>/dev/null; then
        action="replaced"
        tmp="${seed}.seedwork.$$"
        # blk_open/blk_close, not open/close: `close` is an awk builtin and gawk
        # refuses to bind it with -v.
        awk -v blk_open="-- >>> health-seed ${key}" -v blk_close="-- <<< health-seed ${key}" '
            $0 == blk_open  { skipping = 1; next }
            $0 == blk_close { skipping = 0; next }
            skipping        { next }
            { print }
        ' "$seed" > "$tmp" || { rm -f "$tmp"; echo "health-seed: FAILED to rewrite $seed" >&2; return 1; }
        mv "$tmp" "$seed"
    fi

    {
        printf -- '-- >>> health-seed %s\n' "$key"
        printf 'DELETE FROM health_snapshots WHERE session_number = %s AND date = %s;\n' \
            "$session" "$(_health_seed_str "$date")"
        printf 'INSERT INTO health_snapshots (session_number, date, pressure, freshness, coverage, drift, notes) VALUES (%s, %s, %s, %s, %s, %s, %s);\n' \
            "$session" "$(_health_seed_str "$date")" "$p_sql" "$f_sql" "$c_sql" "$d_sql" \
            "$(_health_seed_str "$notes")"
        printf -- '-- <<< health-seed %s\n' "$key"
    } >> "$seed"

    echo "health-seed: ${action} session ${session} (${date}) in scripts/db/data-health.sql — survives the next rebuild"
    return 0
}
