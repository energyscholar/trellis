#!/usr/bin/env bash
# test-directives-reconciled.sh — directives.md and directives-base.md carry
# the same headings, both route to the scripts, and assembly emits the
# GENERATED marker exactly once from either base.
#
# WHY: the two template files had drifted — the assembled file carried three
# blocks (session lifecycle step 0, Mid-Session Event Logging, Session
# Closure) that the base did not, so an install that re-assembled from the
# base silently lost them. The updater copies one into the install as the
# base; whichever it copies, the marker must not multiply.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(dirname "$SCRIPT_DIR")"
T="$REPO/template"

. "$SCRIPT_DIR/lib/guard.sh"

BASE="$T/directives-base.md"
ASM="$T/directives.md"
MARKER='<!-- GENERATED from directives-base.md'

# --- every heading in the assembled file is in the base ---------------------
missing=""
while IFS= read -r h; do
    [ -n "$h" ] || continue
    grep -Fxq "$h" "$BASE" || missing="${missing}${h}
"
done <<EOF
$(grep -E '^##' "$ASM")
EOF
assert_eq "" "$missing" "every ## heading in directives.md is in directives-base.md" || true

# --- both route to the four scripts -----------------------------------------
for script in scripts/recall.sh scripts/record-session.sh scripts/post-update.sh scripts/memory-audit.sh; do
    assert_contains "$(cat "$BASE")" "$script" "directives-base.md names $script" || true
    assert_contains "$(cat "$ASM")"  "$script" "directives.md names $script" || true
done

# --- the marker: first line of the assembled template, absent from the base --
assert_eq "$MARKER" "$(head -1 "$ASM" | cut -c1-${#MARKER})" \
    "directives.md begins with the GENERATED marker" || true
assert_eq "0" "$(grep -c "$MARKER" "$BASE" || true)" \
    "directives-base.md carries no GENERATED marker" || true

# --- assembly from a fixture install: headings ⊇ base, marker exactly once --
WORK=$(mktemp -d "${TMPDIR:-/tmp}/trellis-directives.XXXXXXXX")
trap 'rm -rf "$WORK"' EXIT

assemble_from() {
    # assemble_from BASEFILE — an install whose directives-base.md is BASEFILE
    local src="$1" inst="$WORK/inst-$(basename "$src" .md)"
    rm -rf "$inst"
    mkdir -p "$inst"
    cp -r "$T/scripts" "$T/plugins" "$T/config.yaml" "$inst/"
    cp "$src" "$inst/directives-base.md"
    : > "$inst/.github-setup-complete"
    TRELLIS_HOME="$inst" bash "$inst/scripts/assemble-directives.sh" 2>/dev/null
}

for src in "$BASE" "$ASM"; do
    label=$(basename "$src")
    out=$(assemble_from "$src")
    assert_eq "$MARKER" "$(printf '%s\n' "$out" | head -1 | cut -c1-${#MARKER})" \
        "assembled from $label: first line is the GENERATED marker" || true
    assert_eq "1" "$(printf '%s\n' "$out" | grep -c "$MARKER" || true)" \
        "assembled from $label: the marker appears exactly once" || true
    missing=""
    while IFS= read -r h; do
        [ -n "$h" ] || continue
        printf '%s\n' "$out" | grep -Fxq "$h" || missing="${missing}${h}
"
    done <<EOF
$(grep -E '^##' "$BASE")
EOF
    assert_eq "" "$missing" "assembled from $label: heading set includes every base heading" || true
    assert_contains "$out" "Session lifecycle (FIRST ACTION" \
        "assembled from $label: the once-drifted step 0 survives assembly" || true
    assert_contains "$out" 'read `plugins/dignity-net/dignity-net.md` in full before substantive work' \
        "assembled from $label: active DN requires the complete canonical read" || true
done

guard_summary
