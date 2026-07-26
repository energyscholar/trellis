#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE=$(mktemp -d)
trap 'rm -rf "$FIXTURE"' EXIT

mkdir -p "$FIXTURE/memory" "$FIXTURE/scripts"
cp "$REPO/template/scripts/health-check.sh" "$FIXTURE/scripts/health-check.sh"
cp "$REPO/template/scripts/proprioceptive-check.sh" "$FIXTURE/scripts/proprioceptive-check.sh"
cp "$REPO/template/scripts/memory-sync.sh" "$FIXTURE/scripts/memory-sync.sh"
cp "$REPO/template/scripts/acs-check.sh" "$FIXTURE/scripts/acs-check.sh"
chmod +x "$FIXTURE/scripts/"*.sh

write_config() {
    local cap="$1" trigger="$2" warn="$3"
    printf '%s\n' \
        'version: "0.5.0"' \
        'storage:' \
        '  auto_push: false' \
        'memory:' \
        "  memory_index_cap: $cap" \
        "  compression_trigger: $trigger" \
        'health:' \
        "  pressure_warn: $warn" \
        '  review_interval: 10' \
        'database:' \
        '  enabled: true' \
        '  path: trellis.db' > "$FIXTURE/config.yaml"
}

make_memory_lines() {
    local count="$1"
    awk -v n="$count" 'BEGIN { for (i=1; i<=n; i++) print "memory line " i }' > "$FIXTURE/memory/MEMORY.md"
}

touch "$FIXTURE/memory/protocol.md" "$FIXTURE/memory/corrections.md"
write_config 200 180 0.90
make_memory_lines 180

health_output=$(TRELLIS_HOME="$FIXTURE" bash "$FIXTURE/scripts/health-check.sh" 2>&1)
echo "$health_output" | grep -Eq 'pressure:[[:space:]]+0?\.90[[:space:]]+\[HIGH\]' || {
    echo "health-check did not calculate 180 / 200 as high pressure:" >&2
    echo "$health_output" >&2
    exit 1
}

# Changing configured cap and warning threshold must change the result.
write_config 400 300 0.50
health_output=$(TRELLIS_HOME="$FIXTURE" bash "$FIXTURE/scripts/health-check.sh" 2>&1)
echo "$health_output" | grep -Eq 'pressure:[[:space:]]+0?\.45[[:space:]]+\[OK\]' || {
    echo "health-check did not honor configured cap and warning threshold:" >&2
    echo "$health_output" >&2
    exit 1
}

# An empty health view must fall back to current flat-file pressure.
if command -v sqlite3 >/dev/null 2>&1; then
    sqlite3 "$FIXTURE/trellis.db" \
        'CREATE TABLE health_snapshots (pressure REAL, drift REAL); CREATE VIEW v_health_current AS SELECT pressure, drift FROM health_snapshots;'
    proprio_output=$(TRELLIS_HOME="$FIXTURE" bash "$FIXTURE/scripts/proprioceptive-check.sh" 2>&1)
    echo "$proprio_output" | grep -Eq 'p=0?\.45' || {
        echo "proprioceptive-check kept a false zero for an empty health view:" >&2
        echo "$proprio_output" >&2
        exit 1
    }
fi

# memory-sync warnings must use configured trigger and cap.
write_config 20 10 0.50
make_memory_lines 12
git -C "$FIXTURE" init -q
git -C "$FIXTURE" config user.email test@example.invalid
git -C "$FIXTURE" config user.name "Trellis Test"
git -C "$FIXTURE" add .
git -C "$FIXTURE" commit -qm fixture

set +e
sync_output=$(TRELLIS_HOME="$FIXTURE" bash "$FIXTURE/scripts/memory-sync.sh" --verify-only 2>&1)
sync_status=$?
set -e
[ "$sync_status" -eq 1 ] || {
    echo "memory-sync --verify-only did not flag configured compression trigger" >&2
    exit 1
}
echo "$sync_output" | grep -Fq 'WARNING: MEMORY.md is 12 lines (cap: 20)' || {
    echo "memory-sync warning did not use configured trigger and cap:" >&2
    echo "$sync_output" >&2
    exit 1
}

echo "health diagnostics mechanical fixes: pass"
