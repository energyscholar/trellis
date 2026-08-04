#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
config="$REPO/template/config.yaml"
spec="$REPO/template/plugins/dignity-net/dignity-net.md"
directives="$REPO/template/plugins/dignity-net/directives.md"

fail() {
    echo "dignity-net canon: $*" >&2
    exit 1
}

sha256_file() {
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    elif command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        fail "no SHA-256 tool found"
    fi
}

grep -Fq '**Version:** 1.4 (2026-07-16)' "$spec" \
    || fail "shipped spec is not canonical v1.4"
grep -Fq '## North Star' "$spec" \
    || fail "shipped spec is missing the North Star"
grep -Fq 'Unchecked asymmetry magnifies distortion.' "$spec" \
    || fail "shipped spec is missing the v1.4 asymmetry ontology"
grep -Fq 'affected people can correct, refuse, and recover' "$spec" \
    || fail "shipped spec is missing the v1.4 risk test"
grep -Eq '^[[:space:]]*dn_version:[[:space:]]*"1\.4"' "$config" \
    || fail "template config does not pin DN v1.4"
grep -Fq 'affected people can correct, refuse, and recover' "$directives" \
    || fail "condensed directives omit the v1.4 risk test"

expected=$(grep -E '^[[:space:]]*dn_checksum:' "$config" | head -1 \
    | sed 's/.*dn_checksum:[[:space:]]*//' | tr -d '\r"'"'")
actual=$(sha256_file "$spec")
[ "$expected" = "$actual" ] \
    || fail "configured checksum $expected does not match shipped spec $actual"

echo "dignity-net canon: pass"
