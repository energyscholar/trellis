#!/usr/bin/env bash
# ingest-memories.sh — Parse .md files with YAML frontmatter into SQL INSERT statements.
# Usage:
#   ./ingest-memories.sh --type feedback --glob "memory/feedback-*.md" --output scripts/db/data-feedback.sql
#   ./ingest-memories.sh --file memory/feedback-new-rule.md
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
LOCKFILE="${TRELLIS}/.ingest.lock"

TYPE=""
GLOB_PATTERN=""
OUTPUT=""
SINGLE_FILE=""
CHECK_UNTAGGED=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --type) TYPE="$2"; shift 2 ;;
        --glob) GLOB_PATTERN="$2"; shift 2 ;;
        --output) OUTPUT="$2"; shift 2 ;;
        --file) SINGLE_FILE="$2"; shift 2 ;;
        --check-untagged) CHECK_UNTAGGED=true; shift ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
    esac
done

sql_escape() {
    printf '%s' "$1" | sed "s/'/''/g"
}

extract_frontmatter_field() {
    local file="$1" field="$2"
    sed -n '/^---$/,/^---$/p' "$file" | grep "^${field}:" | head -1 | sed "s/^${field}:[[:space:]]*//"
}

extract_body() {
    local file="$1"
    awk 'BEGIN{n=0} /^---$/{n++; next} n>=2{print}' "$file"
}

get_created_at() {
    local file="$1" established="$2"
    if [ -n "$established" ]; then echo "$established"; return; fi
    local oldest
    oldest=$(git log --date=format:'%Y-%m-%d %H:%M:%S' --format='%ad' -- "$file" 2>/dev/null | tail -1) || true
    if [ -n "$oldest" ]; then echo "$oldest"; return; fi
    date -d "@$(stat -c '%Y' "$file" 2>/dev/null || stat -f '%m' "$file")" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || true
}

get_updated_at() {
    local file="$1"
    local latest
    latest=$(git log -1 --date=format:'%Y-%m-%d %H:%M:%S' --format='%ad' -- "$file" 2>/dev/null) || true
    if [ -n "$latest" ]; then echo "$latest"; return; fi
    date -d "@$(stat -c '%Y' "$file" 2>/dev/null || stat -f '%m' "$file")" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || true
}

extract_body_field() {
    local body="$1" marker="$2"
    echo "$body" | grep -oP "(?<=\*\*${marker}:\*\*\s).*" | head -1
}

extract_first_paragraph() {
    local body="$1"
    echo "$body" | awk '
        /^$/ { if (found) exit; next }
        /^\*\*[A-Z]/ { next }
        /^#/ { next }
        { found=1; print }
    '
}

process_file() {
    local file="$1"
    local filename=$(basename "$file")

    local fm_name=$(extract_frontmatter_field "$file" "name")
    local fm_desc=$(extract_frontmatter_field "$file" "description")
    local fm_domain=$(extract_frontmatter_field "$file" "domain")
    local fm_established=$(extract_frontmatter_field "$file" "established")
    local fm_type=$(extract_frontmatter_field "$file" "type")
    local body=$(extract_body "$file")
    local body_escaped=$(sql_escape "$body")

    local created_at=$(get_created_at "$file" "$fm_established")
    local updated_at=$(get_updated_at "$file")
    local ca_sql; [ -n "$created_at" ] && ca_sql="'${created_at}'" || ca_sql="datetime('now')"
    local ua_sql; [ -n "$updated_at" ] && ua_sql="'${updated_at}'" || ua_sql="datetime('now')"

    local effective_type="${TYPE:-$fm_type}"
    if [ -z "$effective_type" ]; then
        echo "SKIP: $file — no type" >&2
        return
    fi

    local slug
    case "$effective_type" in
        feedback)  slug=$(echo "$filename" | sed 's/^feedback-//; s/\.md$//') ;;
        project)   slug=$(echo "$filename" | sed 's/^project-//; s/\.md$//') ;;
        reference) slug=$(echo "$filename" | sed 's/^reference-//; s/\.md$//') ;;
        user)      slug=$(echo "$filename" | sed 's/^user-//; s/\.md$//') ;;
        *)         slug=$(echo "$filename" | sed 's/\.md$//') ;;
    esac

    local why=$(sql_escape "$(extract_body_field "$body" "Why")")
    local how=$(sql_escape "$(extract_body_field "$body" "How to apply")")

    case "$effective_type" in
        feedback)
            local rule=$(sql_escape "$(extract_first_paragraph "$body")")
            cat <<EOSQL
-- $filename
INSERT OR REPLACE INTO feedback(slug, rule, why, how_to_apply, content, domain, source_file, created_at, updated_at)
VALUES ('$(sql_escape "$slug")', '${rule}', '${why}', '${how}', '${body_escaped}',
    '${fm_domain:-general}', '$(sql_escape "$filename")', ${ca_sql}, ${ua_sql});

EOSQL
            ;;
        project)
            cat <<EOSQL
-- $filename
INSERT OR REPLACE INTO projects(slug, name, description, why, how_to_apply, content, domain, source_file, created_at, updated_at)
VALUES ('$(sql_escape "$slug")', '$(sql_escape "$fm_name")', '$(sql_escape "$fm_desc")',
    '${why}', '${how}', '${body_escaped}',
    '${fm_domain:-general}', '$(sql_escape "$filename")', ${ca_sql}, ${ua_sql});

EOSQL
            ;;
        reference)
            cat <<EOSQL
-- $filename
INSERT OR REPLACE INTO "references"(slug, name, description, source_file, created_at, updated_at)
VALUES ('$(sql_escape "$slug")', '$(sql_escape "$fm_name")', '$(sql_escape "$fm_desc")',
    '$(sql_escape "$filename")', ${ca_sql}, ${ua_sql});

EOSQL
            ;;
        user)
            cat <<EOSQL
-- $filename
INSERT OR REPLACE INTO user_profile(slug, attribute, value, context, source_file, created_at, updated_at)
VALUES ('$(sql_escape "$slug")', '$(sql_escape "$fm_name")', '${body_escaped}',
    '$(sql_escape "$fm_desc")', ${ca_sql}, ${ua_sql});

EOSQL
            ;;
    esac
}

scan_pii() {
    local file="$1"
    local issues=0
    if grep -qiE '(api[_-]?key|password|secret|token|credential)\s*[:=]' "$file" 2>/dev/null; then
        echo "PII WARNING: $file may contain credentials" >&2
        issues=$((issues + 1))
    fi
    if grep -qE '\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b' "$file" 2>/dev/null; then
        echo "PII WARNING: $file may contain email addresses" >&2
        issues=$((issues + 1))
    fi
    return $issues
}

# --check-untagged mode: find .md files without frontmatter type
if [ "$CHECK_UNTAGGED" = true ]; then
    cd "$TRELLIS"
    found=0
    for f in memory/*.md; do
        [ -f "$f" ] || continue
        base=$(basename "$f")
        case "$base" in MEMORY.md|corrections.md|session-details.md|decisions.md|people.md) continue ;; esac
        fm_type=$(extract_frontmatter_field "$f" "type")
        if [ -z "$fm_type" ]; then
            echo "UNTAGGED: $f (no type in frontmatter)" >&2
            found=$((found + 1))
        fi
        scan_pii "$f" || true
    done
    echo "Found $found untagged files"
    exit 0
fi

# Validate args
if [ -z "$SINGLE_FILE" ] && { [ -z "$TYPE" ] || [ -z "$GLOB_PATTERN" ] || [ -z "$OUTPUT" ]; }; then
    echo "Usage: $0 --type TYPE --glob PATTERN --output FILE" >&2
    echo "       $0 --file FILE" >&2
    echo "       $0 --check-untagged" >&2
    exit 1
fi

# Acquire flock
exec 9>"$LOCKFILE"
if ! flock -n 9; then
    echo "ERROR: Another ingest is running" >&2
    exit 1
fi
trap 'rm -f "$LOCKFILE"' EXIT

cd "$TRELLIS"

if [ -n "$SINGLE_FILE" ]; then
    [ ! -f "$SINGLE_FILE" ] && echo "ERROR: $SINGLE_FILE not found" >&2 && exit 1
    process_file "$SINGLE_FILE"
else
    output_path="${TRELLIS}/${OUTPUT}"
    mkdir -p "$(dirname "$output_path")"
    {
        echo "-- Generated by ingest-memories.sh"
        echo "-- Type: $TYPE | Pattern: $GLOB_PATTERN"
        echo "-- Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo ""
    } > "$output_path"

    count=0
    for file in $GLOB_PATTERN; do
        [ -f "$file" ] || continue
        process_file "$file" >> "$output_path"
        count=$((count + 1))
    done
    echo "Processed $count files → $OUTPUT"
fi
