#!/usr/bin/env bash
# rebuild-db.sh — Build trellis.db from schema + data. Atomic swap.
# Flat files remain source of truth. DB is a read cache.
#
# Usage:
#   rebuild-db.sh              Force rebuild
#   rebuild-db.sh --if-stale   Only rebuild if memory files changed since last build
set -euo pipefail

# --- TRELLIS_HOME resolution (canonical — see docs/architecture.md) ---
resolve_trellis_home() {
    if [ -n "${TRELLIS_HOME:-}" ]; then
        echo "$TRELLIS_HOME"
    elif [ -f "$HOME/.config/trellis/home" ]; then
        cat "$HOME/.config/trellis/home"
    else
        echo "$HOME/.trellis"
    fi
}

TRELLIS="$(resolve_trellis_home)"
SCRIPT_DIR="$TRELLIS/scripts"
DB="${TRELLIS}/trellis.db"
DB_NEW="${DB}.new"
DB_BAK="${DB}.bak"
DB_DIR="${SCRIPT_DIR}/db"
DB_CHECKSUM="${TRELLIS}/.db-memory-checksum"

# --- Portable SHA-256 (macOS ships shasum; most Linux ships both) ---
hash_sha256() {
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$@"
    elif command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$@"
    else
        echo "ERROR: no SHA-256 tool found (need shasum or sha256sum)" >&2
        return 1
    fi
}

# --- Staleness check ---
#
# THE KEY MUST COVER THE PIPELINE, NOT JUST ITS INPUT.
#
# This used to hash memory/*.md and nothing else, so every part of the machine
# that TRANSFORMS memory into the database was outside the staleness key.
# Measured: change db/schema.sql and run --if-stale, and you get silence and
# exit 0 — no rebuild. The consequence is not cosmetic. Ship a schema column, a
# new view or a parser change to an existing install and none of it installs,
# because the memory files did not move. The check written to detect the new
# condition then reports zero occurrences — green — having never been built.
#
# So the key is memory content AND pipeline content. A product change to either
# forces exactly one rebuild, and the next --if-stale is a no-op again.
compute_memory_checksum() {
    hash_sha256 "$TRELLIS"/memory/*.md 2>/dev/null | sort | hash_sha256 | awk '{print $1}'
}

compute_pipeline_checksum() {
    local f
    for f in "${DB_DIR}/schema.sql" "${DB_DIR}/views.sql" \
             "${SCRIPT_DIR}/ingest-memories.sh" "${SCRIPT_DIR}/rebuild-db.sh"; do
        [ -f "$f" ] || continue
        hash_sha256 "$f" 2>/dev/null | awk '{print $1}'
    done | sort | hash_sha256 | awk '{print $1}'
}

compute_staleness_key() {
    printf 'memory:%s\npipeline:%s\n' \
        "$(compute_memory_checksum)" "$(compute_pipeline_checksum)" \
        | hash_sha256 | awk '{print $1}'
}

if [ "${1:-}" = "--if-stale" ]; then
    current_checksum=$(compute_staleness_key)
    if [ ! -f "$DB" ]; then
        echo "DB stale (no database at $DB). Building..."
    elif [ ! -f "$DB_CHECKSUM" ]; then
        echo "DB stale (no staleness stamp at $DB_CHECKSUM). Rebuilding..."
    else
        stored_checksum=$(cat "$DB_CHECKSUM" 2>/dev/null || echo "")
        if [ "$current_checksum" = "$stored_checksum" ]; then
            # A decision NOT to act is still a decision, and it says so. The
            # silent exit 0 this replaces was indistinguishable from a rebuild
            # that ran, from a crash, and from a staleness key that had gone
            # blind to the thing that changed.
            echo "db: fresh (memory + pipeline unchanged) — no rebuild"
            exit 0
        fi
        echo "DB stale (memory files or pipeline changed). Rebuilding..."
    fi
fi

cleanup() { rm -f "$DB_NEW" "${DB_NEW}-shm" "${DB_NEW}-wal"; }
restore_backup() {
    echo "ERROR: Verification failed. Restoring backup..." >&2
    rm -f "$DB_NEW"
    [ -f "$DB_BAK" ] && mv "$DB_BAK" "$DB"
    exit 1
}

# Step 1: Back up existing DB
[ -f "$DB" ] && cp "$DB" "$DB_BAK"

# Step 2: Build schema
trap cleanup EXIT
sqlite3 "$DB_NEW" < "${DB_DIR}/schema.sql"
sqlite3 "$DB_NEW" < "${DB_DIR}/views.sql"

#-----------------------------------------------------------------------------
# SNAPSHOT FRESHNESS GATE.
#
# If scripts/db/data-*.sql are generated once and never regenerated, every
# rebuild loads a frozen snapshot and any memory written after that date NEVER
# reaches the DB — silently. Memories stranded this way stay invisible to
# every DB-backed retrieval path while the flat files look perfectly healthy.
#
# A rebuild must NEVER run against a snapshot older than the memory files.
# Regenerate first. This makes that failure structurally impossible.
#-----------------------------------------------------------------------------
_TR_INGEST="${SCRIPT_DIR}/ingest-memories.sh"

# run_ingest LABEL COMMAND... — run one ingest pass and SHOW WHAT IT SAID.
# These calls used to end in `>/dev/null 2>&1 || true`, which threw away
# ingest's own "SKIP: <file> — no type" and "PII WARNING" lines. A memory file
# skipped for a malformed frontmatter block was therefore absent from the
# database while both the file and the rebuild looked perfectly healthy.
# Every line is prefixed, so a SKIP from ingest cannot be mistaken by the test
# runner for a SKIP emitted by a test.
run_ingest() {
    local label="$1"
    shift
    local out rc=0
    out=$("$@" 2>&1) || rc=$?
    if [ -n "$out" ]; then
        printf '%s\n' "$out" | while IFS= read -r _line; do
            printf 'rebuild-db: ingest[%s]: %s\n' "$label" "$_line"
        done
    fi
    if [ "$rc" -ne 0 ]; then
        echo "rebuild-db: ingest[$label] exited $rc — the $label snapshot was NOT regenerated" >&2
    fi
    return 0
}

if [ -x "$_TR_INGEST" ]; then
    _TR_STALE=0
    for _m in "$TRELLIS"/memory/*.md; do
        [ -f "$_m" ] || continue
        for _d in "${SCRIPT_DIR}"/db/data-*.sql; do
            [ -f "$_d" ] || continue
            [ "$_m" -nt "$_d" ] && { _TR_STALE=1; break 2; }
        done
    done
    if [ "$_TR_STALE" -eq 1 ]; then
        echo "rebuild-db: memory is newer than the data snapshot. Regenerating from markdown."
        # NOTE: regenerate ONLY where markdown is the superset. If rows exist
        # only in SQL, extract them to markdown FIRST — or this DELETES them.
        run_ingest feedback   "$_TR_INGEST" --type feedback  --glob "memory/feedback-*.md"  --output scripts/db/data-feedback.sql
        run_ingest projects   "$_TR_INGEST" --type project   --glob "memory/project-*.md"   --output scripts/db/data-projects.sql
        run_ingest references "$_TR_INGEST" --type reference --glob "memory/reference-*.md" --output scripts/db/data-references.sql
        run_ingest user       "$_TR_INGEST" --type user      --glob "memory/user-*.md"      --output scripts/db/data-user.sql
        echo "rebuild-db: snapshot regenerated from markdown."
    fi
fi

# Step 3: Load data (if data scripts exist)
#
# This glob is what carries every table that has no other source across a
# rebuild, health_snapshots included — see scripts/lib/health-seed.sh. Loading
# nothing is a legitimate state (a fresh install) but never a silent one.
_TR_SEEDS=0
for f in "${SCRIPT_DIR}"/db/data-*.sql; do
    [ -f "$f" ] || continue
    sqlite3 "$DB_NEW" < "$f"
    _TR_SEEDS=$((_TR_SEEDS + 1))
done
if [ "$_TR_SEEDS" -eq 0 ]; then
    echo "rebuild-db: no db/data-*.sql seeds found — building from schema only (tables that have no markdown source will be EMPTY)"
else
    _TR_HEALTH=$(sqlite3 "$DB_NEW" "SELECT COUNT(*) FROM health_snapshots;" 2>/dev/null || echo 0)
    echo "rebuild-db: loaded ${_TR_SEEDS} seed file(s); health history: ${_TR_HEALTH} snapshot(s)"
fi

# Step 4: Populate FTS5
sqlite3 "$DB_NEW" <<'FTS'
DELETE FROM memory_fts;

INSERT INTO memory_fts(source_table, source_id, title, content)
SELECT 'corrections', id, title, context FROM corrections
UNION ALL
SELECT 'feedback', id, slug, content FROM feedback
    WHERE opsec_level IS NULL OR opsec_level != 'compartmented'
UNION ALL
SELECT 'projects', id, slug, content FROM projects
    WHERE opsec_level IS NULL OR opsec_level != 'compartmented'
UNION ALL
SELECT 'people', id, name, description FROM people
    WHERE opsec_level IS NULL OR opsec_level != 'compartmented'
UNION ALL
SELECT 'references', id, name, description FROM "references"
    WHERE opsec_level IS NULL OR opsec_level != 'compartmented'
UNION ALL
SELECT 'sessions', id, CAST(number AS TEXT), summary FROM sessions
UNION ALL
SELECT 'decisions', id, topic, decision || ' ' || COALESCE(rationale, '') FROM decisions
UNION ALL
SELECT 'breakthroughs', id, title, description FROM breakthroughs;
FTS

# Step 5: Git-based confidence reinforcement
cd "$TRELLIS"
for f in memory/feedback-*.md memory/project-*.md memory/reference-*.md memory/user-*.md; do
    [ -f "$f" ] || continue
    git_date=$(git log -1 --date=format:'%Y-%m-%d %H:%M:%S' --format='%ad' -- "$f" 2>/dev/null) || true
    [ -z "$git_date" ] && continue
    base=$(basename "$f")
    case "$base" in
        feedback-*)  tbl="feedback"; slug="${base#feedback-}"; slug="${slug%.md}" ;;
        project-*)   tbl="projects"; slug="${base#project-}"; slug="${slug%.md}" ;;
        reference-*) tbl="references"; slug="${base#reference-}"; slug="${slug%.md}" ;;
        user-*)      tbl="user_profile"; slug="${base#user-}"; slug="${slug%.md}" ;;
        *) continue ;;
    esac
    escaped_slug=$(echo "$slug" | sed "s/'/''/g")
    sqlite3 "$DB_NEW" "UPDATE memory_confidence SET last_reinforced = '${git_date}' WHERE source_table = '${tbl}' AND source_id = (SELECT id FROM \"${tbl}\" WHERE slug = '${escaped_slug}');" 2>/dev/null || true
done

# Step 5b: Session-summary reinforcement for non-file-backed tables
sqlite3 "$DB_NEW" <<'REINFORCE'
UPDATE memory_confidence SET last_reinforced = sub.max_date
FROM (
    SELECT p.id, MAX(COALESCE(s.date, s.created_at)) as max_date
    FROM people p, sessions s
    WHERE s.summary LIKE '%' || p.name || '%'
    GROUP BY p.id
) sub
WHERE source_table = 'people' AND source_id = sub.id
AND (last_reinforced IS NULL OR last_reinforced < sub.max_date);

UPDATE memory_confidence SET last_reinforced = sub.max_date
FROM (
    SELECT d.id, MAX(COALESCE(s.date, s.created_at)) as max_date
    FROM decisions d, sessions s
    WHERE s.summary LIKE '%' || d.topic || '%'
    GROUP BY d.id
) sub
WHERE source_table = 'decisions' AND source_id = sub.id
AND (last_reinforced IS NULL OR last_reinforced < sub.max_date);
REINFORCE

# Step 6: Verify
integrity=$(sqlite3 "$DB_NEW" "PRAGMA integrity_check;")
if [ "$integrity" != "ok" ]; then
    echo "PRAGMA integrity_check FAILED: $integrity" >&2
    restore_backup
fi

fk_check=$(sqlite3 "$DB_NEW" "PRAGMA foreign_keys = ON; PRAGMA foreign_key_check;" 2>&1)
if [ -n "$fk_check" ]; then
    echo "PRAGMA foreign_key_check FAILED: $fk_check" >&2
    restore_backup
fi

table_count=$(sqlite3 "$DB_NEW" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'memory_fts%';")
if [ "$table_count" -lt 15 ]; then
    echo "Table count check FAILED: expected >=15, got $table_count" >&2
    restore_backup
fi

# Step 7: Checkpoint WAL and clean sidecars before atomic swap
sqlite3 "$DB_NEW" "PRAGMA wal_checkpoint(TRUNCATE);" 2>/dev/null || true
sqlite3 "$DB_NEW" "PRAGMA journal_mode=DELETE;" 2>/dev/null || true
rm -f "${DB_NEW}-shm" "${DB_NEW}-wal"

trap - EXIT
mv "$DB_NEW" "$DB"
rm -f "${DB}-shm" "${DB}-wal"

# Step 8: Verify final DB after swap (not the temp — the actual artifact)
final_tables=$(sqlite3 "$DB" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'memory_fts%';" 2>/dev/null || echo "0")
final_integrity=$(sqlite3 "$DB" "PRAGMA integrity_check;" 2>/dev/null || echo "FAIL")
if [ "$final_integrity" != "ok" ] || [ "$final_tables" -lt 15 ]; then
    echo "ERROR: Final DB verification failed (tables: $final_tables, integrity: $final_integrity)" >&2
    [ -f "$DB_BAK" ] && mv "$DB_BAK" "$DB"
    exit 1
fi
rm -f "$DB_BAK"

# Step 9: Stamp the staleness key (memory AND pipeline) so --if-stale knows
# this build is fresh. Stamping only the memory half is what let a schema
# change sit uninstalled forever.
compute_staleness_key > "$DB_CHECKSUM"

echo "Rebuild complete: $DB (${final_tables} tables, integrity OK)"
