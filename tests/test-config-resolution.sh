#!/usr/bin/env bash
# test-config-resolution.sh — scripts/lib/config.sh resolves a key to the value
# under ITS OWN section.
#
# THE TRAP THIS TEST IS BUILT AROUND
# ----------------------------------
# The old reader took the first line whose key matched, at any depth. Against a
# config with no duplicated keys that is indistinguishable from correct
# resolution: every assertion passes, and the test proves nothing. So the
# fixture below deliberately carries the collision that broke production —
# memory.enabled: true appears BEFORE database.enabled: false, and a decoy
# path: sits above database.path. A resolution test whose fixture has unique
# keys is a test that cannot fail.
#
# Guards C7 and C8 close the other half: each reverts the fix inside a
# throwaway fixture and requires the assertions to go red.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(dirname "$SCRIPT_DIR")"
LIB="$REPO/template/scripts/lib/config.sh"

. "$SCRIPT_DIR/lib/guard.sh"

WORK=$(mktemp -d "${TMPDIR:-/tmp}/trellis-cfgres.XXXXXXXX")
trap 'rm -rf "$WORK"' EXIT

# --- fixture ----------------------------------------------------------------
# mk_fixture DIR — a config carrying the collision, plus its own copy of the
# lib so a guard can vandalise one without touching the others.
mk_fixture() {
    local dir="$1"
    mkdir -p "$dir/lib"
    cp "$LIB" "$dir/lib/config.sh"
    printf '%s\n' \
        '# Trellis test config' \
        'version: 0.5.0' \
        '' \
        'storage:' \
        '  tier: 1' \
        '  path: decoy-not-the-db.sqlite   # decoy: an earlier bare path:' \
        '' \
        'memory:' \
        '  enabled: true' \
        '  memory_index_cap: 200' \
        '  compression_trigger: 180' \
        '  compression:' \
        '    full_threshold: 0.5' \
        '    summary_threshold: 0.2' \
        '' \
        'plugins:' \
        '  active:' \
        '    - dignity-net' \
        '  dn_version: "1.4"' \
        '' \
        'database:' \
        '  enabled: false                 # the value five scripts could not see' \
        '  path: trellis.db' \
        '  fts5: true' \
        > "$dir/config.yaml"
}

# cfg DIR KEY [DEFAULT] — resolve KEY using DIR's lib and DIR's config.
# Each call sources the lib fresh in a subshell, so a guard's patch (appended
# to that fixture's lib) takes effect on the next call and nothing leaks back
# into this shell.
cfg() {
    local dir="$1" key="$2" default="${3:-}"
    ( config="$dir/config.yaml"; . "$dir/lib/config.sh"; get_config "$key" "$default" )
}

FIX="$WORK/main"
mk_fixture "$FIX"

# --- C1: the bug itself -----------------------------------------------------
# memory.enabled: true is line 9; database.enabled: false is line 22.
assert_eq "false" "$(cfg "$FIX" database.enabled true)" \
    "C1 database.enabled resolves to its own section, not memory.enabled" || true

# --- C2: the shadowing key still resolves ----------------------------------
assert_eq "true" "$(cfg "$FIX" memory.enabled false)" \
    "C2 memory.enabled still resolves" || true

# --- C3: bare keys unchanged (back-compat) ---------------------------------
# Every call site that has not been converted depends on this.
assert_eq "200" "$(cfg "$FIX" memory_index_cap 999)" \
    "C3 bare key resolves as before" || true
assert_eq "180" "$(cfg "$FIX" compression_trigger 999)" \
    "C3 bare key resolves as before (second key)" || true
assert_eq "true" "$(cfg "$FIX" enabled false)" \
    "C3 bare ambiguous key keeps the old first-match answer" || true

# --- C4: three levels -------------------------------------------------------
assert_eq "0.5" "$(cfg "$FIX" memory.compression.full_threshold 9)" \
    "C4 three-level key resolves" || true
assert_eq "0.2" "$(cfg "$FIX" memory.compression.summary_threshold 9)" \
    "C4 three-level key resolves (sibling)" || true

# --- C5: defaults -----------------------------------------------------------
assert_eq "fallback" "$(cfg "$FIX" database.no_such_key fallback)" \
    "C5 section present, key absent, returns the default" || true
assert_eq "fallback" "$(cfg "$FIX" nosuchsection.enabled fallback)" \
    "C5 section absent returns the default (not the bare match)" || true

# --- C6: the decoy path: above database.path -------------------------------
assert_eq "trellis.db" "$(cfg "$FIX" database.path wrong.db)" \
    "C6 database.path is not the earlier storage.path" || true
assert_eq "decoy-not-the-db.sqlite" "$(cfg "$FIX" storage.path wrong)" \
    "C6 storage.path resolves to its own section" || true

# --- C7 GUARD: the bare first-match resolver must break these --------------
register_guard C7 "dotted keys resolve within their section, not by first match"

FIX7="$WORK/guard7"
mk_fixture "$FIX7"

# Append the pre-fix reader. A later definition wins, so this is the old
# behaviour restored inside this fixture only: the dotted key is flattened to
# its leaf and the first match at any depth is taken.
patch_c7() {
    cat >> "$FIX7/lib/config.sh" <<'LEGACY'
get_config() {
    local key="${1##*.}" default="${2:-}" v
    v=$(grep -E "^[[:space:]]*${key}:" "$config" 2>/dev/null | head -1 \
        | sed "s/.*${key}:[[:space:]]*//; s/[[:space:]]*#.*//" | tr -d '\r')
    printf '%s\n' "${v:-$default}"
}
LEGACY
}

assert_c7() {
    assert_eq "false" "$(cfg "$FIX7" database.enabled true)" "C7 database.enabled"
    assert_eq "trellis.db" "$(cfg "$FIX7" database.path wrong.db)" "C7 database.path"
}

prove_guard C7 patch_c7 assert_c7 || true

# --- C8 GUARD: quoted values -----------------------------------------------
# dn_version is written "1.4". health-check.sh compares it to the installed
# plugin's version; an unstripped pair of quotes reports drift forever.
register_guard C8 "surrounding quotes are stripped from values"

FIX8="$WORK/guard8"
mk_fixture "$FIX8"

patch_c8() {
    cat >> "$FIX8/lib/config.sh" <<'NOSTRIP'
_config_strip_quotes() { printf '%s\n' "$1"; }
NOSTRIP
}

assert_c8() {
    assert_eq "1.4" "$(cfg "$FIX8" plugins.dn_version 0)" "C8 dn_version unquoted"
}

prove_guard C8 patch_c8 assert_c8 || true

guard_summary
