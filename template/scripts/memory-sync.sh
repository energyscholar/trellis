#!/usr/bin/env bash
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

if [ ! -d "$TRELLIS" ]; then
    echo "Trellis not found at $TRELLIS" >&2
    exit 1
fi

cd "$TRELLIS"

# DISTRIBUTION REPO GUARD: refuse to sync if this is the distribution repo
if [ -f "$TRELLIS/.trellis-distribution" ]; then
    echo "REFUSED: This is the Trellis distribution repo, not your install." >&2
    echo "Install first: copy template/ to ~/.trellis/ (see docs/install.md)" >&2
    exit 1
fi
if [ -d "$TRELLIS/template" ] && [ -d "$TRELLIS/tests" ]; then
    echo "REFUSED: This looks like the distribution repo (has template/ and tests/)." >&2
    echo "Install first: copy template/ to ~/.trellis/ (see docs/install.md)" >&2
    exit 1
fi

# Parse flags
QUICK=false
VERIFY_ONLY=false
for arg in "$@"; do
    case "$arg" in
        --quick) QUICK=true ;;
        --verify-only) VERIFY_ONLY=true ;;
    esac
done

# T0 mode: no git = no sync
if ! command -v git &>/dev/null; then
    exit 0
fi

if ! git rev-parse --git-dir &>/dev/null; then
    exit 0
fi

# Clear dirty flag
rm -f "$TRELLIS/.session-active"

HASHES="$TRELLIS/.file-hashes"
WARNINGS=0

# --- Portable SHA-256 (macOS ships shasum; most Linux ships both) ---
# A missing hash tool must FAIL LOUD: an empty hash file makes drift detection
# silently report "no changes" forever — the silent-success failure class.
hash_sha256() {
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$@"
    elif command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$@"
    else
        echo "ERROR: no SHA-256 tool found (need shasum or sha256sum). Sync aborted." >&2
        exit 1
    fi
}

# Portable file mtime (epoch). GNU long form first: on GNU, `stat -f` means
# "filesystem status" and would succeed with the WRONG output.
file_mtime_epoch() {
    stat --format='%Y' "$1" 2>/dev/null || stat -f '%m' "$1" 2>/dev/null
}

if ! $QUICK; then
    # Health warnings
    if [ -f "$TRELLIS/memory/MEMORY.md" ]; then
        LINES=$(wc -l < "$TRELLIS/memory/MEMORY.md")
        [ "$LINES" -ge 180 ] && echo "WARNING: MEMORY.md is $LINES lines (cap: 200)" && WARNINGS=$((WARNINGS+1))
    fi

    # CRLF detection
    CRLF=$(file "$TRELLIS"/memory/*.md 2>/dev/null | grep CRLF | cut -d: -f1 || true)
    [ -n "$CRLF" ] && echo "WARNING: CRLF in: $CRLF" && WARNINGS=$((WARNINGS+1))
fi

# Checksum drift detection
if [ -f "$HASHES" ]; then
    HASHES_NEW=$(mktemp)
    hash_sha256 "$TRELLIS"/memory/*.md 2>/dev/null > "$HASHES_NEW"
    DRIFTED=$(diff "$HASHES" "$HASHES_NEW" 2>/dev/null | grep "^>" | awk '{print $NF}' || true)
    rm -f "$HASHES_NEW"
    if [ -n "$DRIFTED" ] && ! $QUICK; then
        echo "INFO: Changed since last sync: $DRIFTED"
    fi
    if $QUICK && [ -z "$DRIFTED" ]; then
        exit 0
    fi
fi

if $VERIFY_ONLY; then
    echo "Verify-only: $WARNINGS warning(s)."
    exit $( [ "$WARNINGS" -gt 0 ] && echo 1 || echo 0 )
fi

# Stage and commit (explicit paths — avoid committing stray credentials)
git add memory/ config.yaml profiles/ plugins/ scripts/ .file-hashes .db-memory-checksum .gitignore 2>/dev/null || true
hash_sha256 "$TRELLIS"/memory/*.md 2>/dev/null > "$HASHES"
git add "$HASHES"

if git diff --cached --quiet; then
    echo "Memory sync: no changes to commit."
    exit 0
fi

git commit -m "Memory sync: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Memory synced: $(git log --oneline -1)"

# --- Remote push (T2+) ---

if ! git remote get-url origin &>/dev/null; then
    exit 0
fi

if $QUICK; then
    exit 0
fi

# Respect auto_push config (update script checks this; we must too)
AUTO_PUSH=$(grep -E '^\s*auto_push:' "$TRELLIS/config.yaml" 2>/dev/null \
    | head -1 | sed 's/.*auto_push:[[:space:]]*//' | tr -d '\r' || true)
if [ "$AUTO_PUSH" = "false" ]; then
    echo "Remote configured but auto_push is false. Skipping push."
    exit 0
fi

# Handle git lock contention
if [ -f .git/index.lock ]; then
    lock_age=$(( $(date +%s) - $(file_mtime_epoch .git/index.lock) ))
    if [ "$lock_age" -gt 300 ]; then
        rm -f .git/index.lock
    else
        for delay in 1 2 4; do
            sleep "$delay"
            [ ! -f .git/index.lock ] && break
        done
        if [ -f .git/index.lock ]; then
            echo "Warning: git lock held. Push skipped."
            exit 0
        fi
    fi
fi

remote_url=$(git remote get-url origin)

# UPSTREAM DISTRIBUTION GUARD: never push to the trellis distribution repo
if echo "$remote_url" | grep -qiE 'energyscholar/trellis(\.git)?$'; then
    echo "REFUSED: Remote points to the Trellis distribution repo." >&2
    echo "Your personal memories must NOT go to the distribution repo." >&2
    echo "Fix: create your own private repo and set it as origin." >&2
    exit 1
fi

# PUBLIC REPO GUARD (GitHub only)
if [[ "$remote_url" == *github.com* ]] && command -v gh &>/dev/null; then
    repo_path=$(echo "$remote_url" | sed 's|.*github.com[:/]||; s|\.git$||')
    visibility=$(gh repo view "$repo_path" --json visibility \
                 --jq '.visibility' 2>/dev/null || echo "UNKNOWN")
    if [ "$visibility" = "PUBLIC" ]; then
        echo "REFUSED: $repo_path is PUBLIC. Memories NOT pushed." >&2
        echo "Your memories would be visible to everyone." >&2
        echo "Fix: gh repo edit $repo_path --visibility private" >&2
        exit 1
    fi
fi

# Pull before push (multi-machine sync). Never assume a branch name —
# installs exist on both main and master.
current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [ -n "$current_branch" ] && [ "$current_branch" != "HEAD" ]; then
    git pull --rebase origin "$current_branch" 2>/dev/null || true
fi

# Push with retry
pushed=false
for delay in 0 2 4; do
    [ "$delay" -gt 0 ] && sleep "$delay"
    if git push 2>/dev/null; then
        pushed=true
        break
    fi
done

if [ "$pushed" = false ]; then
    echo "Warning: push failed (offline?). Local commit preserved."
fi
