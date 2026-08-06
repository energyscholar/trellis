#!/usr/bin/env bash
# lib/config.sh — the one config reader. Source it; do not execute it.
#
#     SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
#     . "$SCRIPT_DIR/lib/config.sh"
#     config="$TRELLIS/config.yaml"
#     db_enabled=$(get_config "database.enabled" "true")
#
# WHY THIS FILE EXISTS
# --------------------
# get_config used to be copy-pasted into five scripts, each a one-liner:
#
#     grep -E "^\s*KEY:" "$config" | head -1 | sed ... | tr -d '\r'
#
# That takes the FIRST line whose key matches, at ANY nesting depth. config.yaml
# has four bare keys that appear twice (enabled, corrections, ptl, breakthroughs),
# so `get_config "enabled"` returned memory.enabled — never database.enabled,
# which is 80 lines further down. Consequence: setting database.enabled: false
# did nothing. health-check.sh rebuilt the database and reported "sqlite: ON"
# against a config that had switched it off, and the documented flat-file mode
# had never once worked. A duplicated reader also means a fix has to be found
# and applied five times; this file is so that it is applied once.
#
# CONTRACT
#   get_config KEY [DEFAULT]
#     KEY without a dot   first match at any depth (unchanged from the old
#                         behaviour, so every existing call site keeps working)
#     KEY with dots       resolved within its parent path: database.enabled
#                         reads the enabled under database:, and
#                         memory.compression.full_threshold nests three deep
#     DEFAULT             returned when the key is absent, when its section is
#                         absent, and when no config file is readable
#
#   The value has its inline comment removed, surrounding whitespace trimmed,
#   and ONE layer of matching quotes stripped. The quote stripping is load
#   bearing: dn_version is written "1.4" in config.yaml, and a caller comparing
#   it to 1.4 would otherwise report Dignity Net drift forever.
#
#   The file read is $config, or $TRELLIS_CONFIG when set.
#
# Portability: POSIX awk/grep/sed only. No PyYAML, no yq, no grep -P, no sed -i.
# bash 3.2 and BSD userland (macOS is in CI, and tests/test-portability.sh
# enforces it).
#
# This is NOT a YAML parser. It reads the flat "key: scalar" config.yaml this
# project ships and nothing more: no flow mappings, no anchors, no multi-line
# scalars. If config.yaml ever needs those, it needs a real parser, not a
# widening of this file.

# _config_strip_quotes VALUE — remove one layer of surrounding quotes.
# Split out so it is one obvious thing to keep, and one obvious thing for a
# guard test to remove when it needs to prove the quote stripping is watched.
_config_strip_quotes() {
    local v="$1"
    case "$v" in
        \"*\") v="${v#\"}"; v="${v%\"}" ;;
        \'*\') v="${v#\'}"; v="${v%\'}" ;;
    esac
    printf '%s\n' "$v"
}

# get_config KEY [DEFAULT]
get_config() {
    local key="${1:-}" default="${2:-}"
    local file="${TRELLIS_CONFIG:-${config:-}}"
    local want leaf bare value

    if [ -z "$key" ] || [ -z "$file" ] || [ ! -f "$file" ]; then
        printf '%s\n' "$default"
        return 0
    fi

    case "$key" in
        *.*) want="${key%.*}"; leaf="${key##*.}"; bare=0 ;;
        *)   want=""; leaf="$key"; bare=1 ;;
    esac

    # One awk pass. It rebuilds the dotted path of each "key:" line from the
    # indentation stack, so a leaf is matched together with its parents rather
    # than on its own name. Exit status 1 means "not found", which is how the
    # default is told apart from a key whose value really is empty.
    value=$(awk -v want="$want" -v leaf="$leaf" -v bare="$bare" '
        function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
        {
            line = $0
            sub(/\r$/, "", line)
            if (line ~ /^[ \t]*$/) next
            if (line ~ /^[ \t]*#/) next
            p = match(line, /[^ ]/)
            if (p == 0) next
            ind = p - 1
            rest = substr(line, p)
            # Only "name:" lines carry a key. List items ("- x") and anything
            # else are skipped, and must not disturb the indentation stack.
            if (rest !~ /^[A-Za-z0-9_][A-Za-z0-9_.-]*:/) next
            ci = index(rest, ":")
            k = substr(rest, 1, ci - 1)
            v = substr(rest, ci + 1)
            hi = index(v, "#")
            if (hi > 0) v = substr(v, 1, hi - 1)
            v = trim(v)

            while (n > 0 && stkind[n] >= ind) n--
            n++
            stkind[n] = ind
            stkkey[n] = k

            path = ""
            for (i = 1; i < n; i++) path = (i == 1 ? stkkey[i] : path "." stkkey[i])

            if (bare == "1") {
                if (k == leaf) { print v; found = 1; exit 0 }
            } else if (k == leaf && path == want) {
                print v; found = 1; exit 0
            }
        }
        END { if (!found) exit 1 }
    ' "$file") || { printf '%s\n' "$default"; return 0; }

    _config_strip_quotes "$value"
}
