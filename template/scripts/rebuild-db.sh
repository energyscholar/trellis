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

# --- Staleness check ---
compute_memory_checksum() {
    md5sum "$TRELLIS"/memory/*.md 2>/dev/null | sort | md5sum | awk '{print $1}'
}

if [ "${1:-}" = "--if-stale" ]; then
    current_checksum=$(compute_memory_checksum)
    if [ -f "$DB" ] && [ -f "$DB_CHECKSUM" ]; then
        stored_checksum=$(cat "$DB_CHECKSUM" 2>/dev/null || echo "")
        if [ "$current_checksum" = "$stored_checksum" ]; then
            exit 0
        fi
    fi
    echo "DB stale (memory files changed). Rebuilding..."
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

# Step 3: Load data (if data scripts exist)
for f in "${SCRIPT_DIR}"/db/data-*.sql; do
    [ -f "$f" ] || continue
    sqlite3 "$DB_NEW" < "$f"
done

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
    sqlite3 "$DB_NEW" "UPDATE memory_confidence SET last_reinforced = '${git_date}' WHERE source_table = '${tbl}' AND source_id = (SELECT id FROM \"${tbl}\" WHERE slug = '${slug}');" 2>/dev/null || true
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

# Step 9: Stamp memory checksum so --if-stale knows this build is fresh
compute_memory_checksum > "$DB_CHECKSUM"

echo "Rebuild complete: $DB (${final_tables} tables, integrity OK)"
