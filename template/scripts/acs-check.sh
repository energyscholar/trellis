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

config="$TRELLIS/config.yaml"
session_log="$TRELLIS/memory/session-log.md"

get_config() {
    local key="$1" default="$2"
    grep -E "^\s*${key}:" "$config" 2>/dev/null | head -1 | sed "s/.*${key}:[[:space:]]*//; s/[[:space:]]*#.*//" | tr -d '\r' || echo "$default"
}

acs_window=$(get_config "acs_window" "20")
acs_min_sessions="${ACS_MIN_SESSIONS:-$(get_config "acs_min_sessions" "10")}"
oneliner="${1:-}"

# --- Parse session log ---
if [ ! -f "$session_log" ]; then
    if [ "$oneliner" = "--oneliner" ]; then
        echo "  acs:           -- (no session log)"
    else
        echo "ACS: no session-log.md found"
    fi
    exit 0
fi

# Extract data rows (skip header, empty lines, separator lines)
session_data=$(awk -F'|' '
    /^\| S[0-9]/ {
        gsub(/^[ \t]+|[ \t]+$/, "", $2)  # session
        gsub(/^[ \t]+|[ \t]+$/, "", $3)  # date
        gsub(/^[ \t]+|[ \t]+$/, "", $4)  # domain
        gsub(/^[ \t]+|[ \t]+$/, "", $5)  # memory
        gsub(/^[ \t]+|[ \t]+$/, "", $6)  # structure
        gsub(/^[ \t]+|[ \t]+$/, "", $7)  # ethics
        print $2 "|" $3 "|" $4 "|" $5 "|" $6 "|" $7
    }
' "$session_log")

if [ -z "$session_data" ]; then
    total_sessions=0
else
    total_sessions=$(echo "$session_data" | wc -l | tr -d ' ')
fi

if [ "$total_sessions" -lt "$acs_min_sessions" ]; then
    if [ "$oneliner" = "--oneliner" ]; then
        echo "  acs:           -- (need ${acs_min_sessions}+ sessions, have $total_sessions)"
    else
        echo "ACS: insufficient data (need $acs_min_sessions+ sessions, have $total_sessions)"
    fi
    exit 0
fi

# Take last N sessions (window)
windowed=$(echo "$session_data" | tail -n "$acs_window")
window_size=$(echo "$windowed" | grep -c '.' 2>/dev/null || echo 0)
first_session=$(echo "$windowed" | head -1 | cut -d'|' -f1)
last_session=$(echo "$windowed" | tail -1 | cut -d'|' -f1)
first_date=$(echo "$windowed" | head -1 | cut -d'|' -f2)
last_date=$(echo "$windowed" | tail -1 | cut -d'|' -f2)

# --- Compute per-axis activity and catalysis matrix ---
# Uses co-occurrence of reinforcement events per directed edge.
# Catalysis m_ij = P(reinforcement event on edge i->j) across sessions in window.
#
# Edge definitions (A fires, B responds in same session):
#   M->S: correction in M AND (drift-resolved OR follow) in S
#   M->E: (correction OR save) in M AND (l1+ OR divergence) in E
#   S->M: plan in S AND (compress OR save) in M
#   S->E: (plan OR follow) in S AND (l0 present, no l2+ = baseline holds)
#   E->M: (l1+ OR divergence) in E AND correction in M
#   E->S: divergence in E AND (drift-flag OR drift-resolved) in S

# --- Provenance-aware awk pass ---
# Strips source annotations (e), (s) before edge checks (backward compatible).
# Counts per-source events. Writes per-session edge data to tempfile for RWI pass.

prov_tmp=$(mktemp)
trap 'rm -f "$prov_tmp"' EXIT

read -r m_activity s_activity e_activity \
       m_to_s m_to_e s_to_m s_to_e e_to_m e_to_s \
       total_events human_events env_events sys_events <<< "$(echo "$windowed" | awk -F'|' -v prov_file="$prov_tmp" '
function event_source(ev) {
    if (ev ~ /\(e\)[[:space:]]*$/) return "e"
    if (ev ~ /\(s\)[[:space:]]*$/) return "s"
    return "h"
}
function field_has_src(field, pat,    i, nf, parts, ev, stripped) {
    nf = split(field, parts, /,/)
    for (i = 1; i <= nf; i++) {
        ev = parts[i]; gsub(/^[ \t]+|[ \t]+$/, "", ev)
        stripped = ev; gsub(/\([ehs]\)[[:space:]]*$/, "", stripped); gsub(/[ \t]+$/, "", stripped)
        if (stripped ~ pat) { _src = event_source(ev); return 1 }
    }
    _src = "h"; return 0
}
BEGIN {
    n=0; ma=0; sa=0; ea=0; ms=0; me=0; sm=0; se=0; em=0; es=0
    total_ev=0; human_ev=0; env_ev=0; sys_ev=0
}
{
    n++
    raw_mem = $4; raw_str = $5; raw_eth = $6
    mem = raw_mem; str = raw_str; eth = raw_eth

    # --- Count per-event sources across all axes ---
    for (axis_idx = 4; axis_idx <= 6; axis_idx++) {
        nf = split($axis_idx, parts, /,/)
        for (i = 1; i <= nf; i++) {
            ev = parts[i]; gsub(/^[ \t]+|[ \t]+$/, "", ev)
            if (ev == "" || ev ~ /^[-\342\200\224]?$/) continue
            total_ev++
            s = event_source(ev)
            if (s == "e") env_ev++
            else if (s == "s") sys_ev++
            else human_ev++
        }
    }

    # --- Strip annotations from fields for activity + edge checks ---
    gsub(/\([ehs]\)/, "", mem); gsub(/\([ehs]\)/, "", str); gsub(/\([ehs]\)/, "", eth)

    # Per-axis activity (any non-trivial event) — UNCHANGED logic
    has_m = (mem !~ /^[-\342\200\224]?$/ && mem != "")
    has_s = (str !~ /^[-\342\200\224]?$/ && str != "")
    has_e = (eth !~ /^[-\342\200\224]?$/ && eth != "" && eth !~ /^l0$/)

    if (has_m) ma++
    if (has_s) sa++
    if (has_e) ea++

    # Atomic event flags — UNCHANGED logic (annotations already stripped)
    m_correction = (mem ~ /correction/)
    m_save       = (mem ~ /save/)
    m_compress   = (mem ~ /compress/)
    s_plan       = (str ~ /plan/)
    s_follow     = (str ~ /follow/)
    s_drift_flag = (str ~ /drift-flag/)
    s_drift_res  = (str ~ /drift-resolved/)
    e_l1plus     = (eth ~ /l[1-5]/)
    e_divergence = (eth ~ /divergence/)
    e_l0_only    = (eth ~ /l0/ && !e_l1plus && !e_divergence)

    # Cross-axis catalysis (co-occurrence) — UNCHANGED logic
    if (m_correction && (s_drift_res || s_follow))  ms++
    if ((m_correction || m_save) && (e_l1plus || e_divergence))  me++
    if (s_plan && (m_compress || m_save))  sm++
    if ((s_plan || s_follow) && e_l0_only)  se++
    if ((e_l1plus || e_divergence) && m_correction)  em++
    if (e_divergence && (s_drift_flag || s_drift_res))  es++

    # --- Per-session edge firing + source data for RWI pass ---
    ms_fired = (m_correction && (s_drift_res || s_follow)) ? 1 : 0
    me_fired = ((m_correction || m_save) && (e_l1plus || e_divergence)) ? 1 : 0
    sm_fired = (s_plan && (m_compress || m_save)) ? 1 : 0
    se_fired = ((s_plan || s_follow) && e_l0_only) ? 1 : 0
    em_fired = ((e_l1plus || e_divergence) && m_correction) ? 1 : 0
    es_fired = (e_divergence && (s_drift_flag || s_drift_res)) ? 1 : 0

    # Determine if constituent events for each firing edge contain any human source.
    # has_human_src = 1 if ANY constituent event is human-sourced, else 0.
    # For RWI: recovery is human-free only when has_human_src = 0.
    ms_hsrc = 1; me_hsrc = 1; sm_hsrc = 1; se_hsrc = 1; em_hsrc = 1; es_hsrc = 1

    if (ms_fired) {
        field_has_src(raw_mem, "correction"); s1 = _src
        if (field_has_src(raw_str, "drift-resolved")) s2 = _src
        else { field_has_src(raw_str, "follow"); s2 = _src }
        ms_hsrc = (s1 == "h" || s2 == "h") ? 1 : 0
    }
    if (me_fired) {
        if (field_has_src(raw_mem, "correction")) s1 = _src
        else { field_has_src(raw_mem, "save"); s1 = _src }
        if (field_has_src(raw_eth, "l[1-5]")) s2 = _src
        else { field_has_src(raw_eth, "divergence"); s2 = _src }
        me_hsrc = (s1 == "h" || s2 == "h") ? 1 : 0
    }
    if (sm_fired) {
        field_has_src(raw_str, "plan"); s1 = _src
        if (field_has_src(raw_mem, "compress")) s2 = _src
        else { field_has_src(raw_mem, "save"); s2 = _src }
        sm_hsrc = (s1 == "h" || s2 == "h") ? 1 : 0
    }
    if (se_fired) {
        if (field_has_src(raw_str, "plan")) s1 = _src
        else { field_has_src(raw_str, "follow"); s1 = _src }
        field_has_src(raw_eth, "l0"); s2 = _src
        se_hsrc = (s1 == "h" || s2 == "h") ? 1 : 0
    }
    if (em_fired) {
        if (field_has_src(raw_eth, "l[1-5]")) s1 = _src
        else { field_has_src(raw_eth, "divergence"); s1 = _src }
        field_has_src(raw_mem, "correction"); s2 = _src
        em_hsrc = (s1 == "h" || s2 == "h") ? 1 : 0
    }
    if (es_fired) {
        field_has_src(raw_eth, "divergence"); s1 = _src
        if (field_has_src(raw_str, "drift-flag")) s2 = _src
        else { field_has_src(raw_str, "drift-resolved"); s2 = _src }
        es_hsrc = (s1 == "h" || s2 == "h") ? 1 : 0
    }

    # Write per-session edge data: fired(0/1) has_human(0/1) per edge
    printf "%d %d %d %d %d %d %d %d %d %d %d %d %d\n", \
        n, ms_fired, me_fired, sm_fired, se_fired, em_fired, es_fired, \
        ms_hsrc, me_hsrc, sm_hsrc, se_hsrc, em_hsrc, es_hsrc \
        >> prov_file
}
END {
    if (n == 0) n = 1
    printf "%.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %d %d %d %d\n", \
        ma/n, sa/n, ea/n, ms/n, me/n, sm/n, se/n, em/n, es/n, \
        total_ev, human_ev, env_ev, sys_ev
}
')"

# --- Solve depressed cubic for eigenvalues ---
# Catalytic matrix M (zero diagonal):
#   [[  0,   m12, m13 ],     m12=m_to_s  m13=m_to_e
#    [  m21, 0,   m23 ],     m21=s_to_m  m23=s_to_e
#    [  m31, m32, 0   ]]     m31=e_to_m  m32=e_to_s
#
# Characteristic polynomial (zero-diagonal 3x3):
#   lambda^3 - S*lambda - D = 0
# where S = m12*m21 + m13*m31 + m23*m32  (edge-pair products)
#       D = m12*m23*m31 + m13*m21*m32    (3-cycle products)

read -r lambda1 lambda2 lambda3 spectral_gap S_val D_val <<< "$(awk -v m12="$m_to_s" -v m13="$m_to_e" \
    -v m21="$s_to_m" -v m23="$s_to_e" \
    -v m31="$e_to_m" -v m32="$e_to_s" '
BEGIN {
    pi = 3.14159265358979323846

    S = m12*m21 + m13*m31 + m23*m32
    D = m12*m23*m31 + m13*m21*m32

    if (S < 0.0001) {
        # Near-zero matrix — no catalysis
        printf "0.0000 0.0000 0.0000 0.0000 %.4f %.4f\n", S, D
        exit
    }

    # Depressed cubic: t^3 - S*t - D = 0
    # Discriminant: delta = 4*S^3 - 27*D^2
    delta = 4*S*S*S - 27*D*D

    if (delta >= 0) {
        # Three real roots — trigonometric method
        m = 2 * sqrt(S/3)
        arg = (3*sqrt(3)*D) / (2 * S * sqrt(S))
        # Clamp to [-1,1] for numerical safety
        if (arg > 1) arg = 1
        if (arg < -1) arg = -1
        theta = atan2(sqrt(1 - arg*arg), arg) / 3

        t1 = m * cos(theta)
        t2 = m * cos(theta - 2*pi/3)
        t3 = m * cos(theta - 4*pi/3)
    } else {
        # One real root, two complex conjugates — Cardano
        q_half = -D / 2
        r = q_half*q_half + (-S/3)*(-S/3)*(-S/3)
        # r < 0 when delta < 0... actually for depressed cubic t^3 + pt + q:
        # Our form: t^3 + (-S)*t + (-D) = 0, so p = -S, q = -D
        p = -S; q = -D
        disc = q*q/4 + p*p*p/27
        if (disc < 0) disc = 0
        sd = sqrt(disc)

        u = -q/2 + sd
        v = -q/2 - sd

        # Cube roots (handle sign)
        if (u >= 0) u3 = u^(1/3); else u3 = -((-u)^(1/3))
        if (v >= 0) v3 = v^(1/3); else v3 = -((-v)^(1/3))

        t1 = u3 + v3
        # Complex conjugate pair — magnitude only
        t2 = -t1/2
        t3 = t2
    }

    # Sort descending
    if (t2 > t1) { tmp=t1; t1=t2; t2=tmp }
    if (t3 > t1) { tmp=t1; t1=t3; t3=tmp }
    if (t3 > t2) { tmp=t2; t2=t3; t3=tmp }

    gap = t1 - t2
    if (gap < 0) gap = -gap

    printf "%.4f %.4f %.4f %.4f %.4f %.4f\n", t1, t2, t3, gap, S, D
}
')"

# --- Determine status ---
if awk "BEGIN { exit ($lambda1 > 1.0) ? 0 : 1 }" 2>/dev/null; then
    status="SUPERCRITICAL"
elif awk "BEGIN { exit ($lambda1 > 0.8) ? 0 : 1 }" 2>/dev/null; then
    status="NEAR-CRITICAL"
elif awk "BEGIN { exit ($lambda1 > 0.0001) ? 0 : 1 }" 2>/dev/null; then
    status="SUBCRITICAL"
else
    status="DORMANT"
fi

# --- Find weakest edge ---
weakest_label=""
weakest_val="999"
check_edge() {
    local label="$1" val="$2"
    if awk -v v="$val" -v w="$weakest_val" 'BEGIN { exit (v < w) ? 0 : 1 }' 2>/dev/null; then
        weakest_label="$label"
        weakest_val="$val"
    fi
}
check_edge "M→S" "$m_to_s"
check_edge "M→E" "$m_to_e"
check_edge "S→M" "$s_to_m"
check_edge "S→E" "$s_to_e"
check_edge "E→M" "$e_to_m"
check_edge "E→S" "$e_to_s"

# --- Recovery-without-intervention (RWI) ---
# Per-edge cold-streak algorithm. An edge is "weak" after COLD_THRESHOLD
# consecutive non-firings. When a weak edge fires with no human-sourced
# constituent events, that's a human-free recovery.
COLD_THRESHOLD=3

read -r rwi_total rwi_ms rwi_me rwi_sm rwi_se rwi_em rwi_es <<< "$(awk -v threshold="$COLD_THRESHOLD" '
BEGIN {
    # Per-edge state: cold_streak, in_weakness, ever_fired, rwi
    for (i = 1; i <= 6; i++) {
        cold[i] = 0; weak[i] = 0; fired_ever[i] = 0; rwi[i] = 0
    }
}
{
    # Fields: session_idx ms_fired me_fired sm_fired se_fired em_fired es_fired
    #         ms_hsrc me_hsrc sm_hsrc se_hsrc em_hsrc es_hsrc
    for (i = 1; i <= 6; i++) {
        edge_fired = $(i + 1)    # columns 2-7: fired flags
        has_human  = $(i + 7)    # columns 8-13: human source flags

        if (edge_fired) {
            if (weak[i] && fired_ever[i]) {
                # Recovery from weakness — check if human-free
                if (!has_human) rwi[i]++
            }
            cold[i] = 0
            weak[i] = 0
            fired_ever[i] = 1
        } else {
            cold[i]++
            if (cold[i] >= threshold) weak[i] = 1
        }
    }
}
END {
    total = rwi[1]+rwi[2]+rwi[3]+rwi[4]+rwi[5]+rwi[6]
    printf "%d %d %d %d %d %d %d\n", total, rwi[1], rwi[2], rwi[3], rwi[4], rwi[5], rwi[6]
}
' "$prov_tmp")"

# --- One-liner mode (for health-check integration) ---
if [ "$oneliner" = "--oneliner" ]; then
    printf "  acs:           λ=%.2f gap=%.2f weak=%s(%.2f) rwi=%d [%s]\n" \
        "$lambda1" "$spectral_gap" "$weakest_label" "$weakest_val" "$rwi_total" "$status"
    exit 0
fi

# --- Full report ---
bar() {
    local val="$1" width=10
    local filled=$(awk -v v="$val" -v w="$width" 'BEGIN { f=int(v*w+0.5); if(f>w)f=w; if(f<0)f=0; print f }')
    local empty=$((width - filled))
    [ "$filled" -gt 0 ] && printf '%0.s█' $(seq 1 "$filled") || true
    [ "$empty" -gt 0 ] && printf '%0.s░' $(seq 1 "$empty") || true
}

echo "Trellis ACS Report"
echo "=================="
echo "Sessions: $window_size ($first_session–$last_session)  Window: $first_date — $last_date"
echo ""
echo "Per-Axis Activity:"
printf "  Memory:    %s  %.2f\n" "$(bar "$m_activity")" "$m_activity"
printf "  Structure: %s  %.2f\n" "$(bar "$s_activity")" "$s_activity"
printf "  Ethics:    %s  %.2f\n" "$(bar "$e_activity")" "$e_activity"
echo ""
echo "Catalysis (K3):"
printf "            → Mem    → Str    → Eth\n"
printf "  Mem →      ——     %5.2f    %5.2f" "$m_to_s" "$m_to_e"
[ "$weakest_label" = "M→S" ] || [ "$weakest_label" = "M→E" ] && printf "  ← weakest"
echo ""
printf "  Str →    %5.2f     ——     %5.2f" "$s_to_m" "$s_to_e"
[ "$weakest_label" = "S→M" ] || [ "$weakest_label" = "S→E" ] && printf "  ← weakest"
echo ""
printf "  Eth →    %5.2f    %5.2f     ——" "$e_to_m" "$e_to_s"
[ "$weakest_label" = "E→M" ] || [ "$weakest_label" = "E→S" ] && printf "  ← weakest"
echo ""
echo ""
printf "  λ₁ = %.2f  %s\n" "$lambda1" "$status"
printf "  Spectral gap = %.2f" "$spectral_gap"
if awk "BEGIN { exit ($spectral_gap > 0.5) ? 0 : 1 }" 2>/dev/null; then
    echo "  RESILIENT"
elif awk "BEGIN { exit ($spectral_gap > 0.2) ? 0 : 1 }" 2>/dev/null; then
    echo "  MODERATE"
else
    echo "  FRAGILE"
fi
printf "  Weakest: %s (%.2f)\n" "$weakest_label" "$weakest_val"
echo ""

# --- Provenance histogram ---
if [ "$total_events" -gt 0 ]; then
    human_pct=$(awk -v h="$human_events" -v t="$total_events" 'BEGIN { printf "%d", (h/t)*100+0.5 }')
    env_pct=$(awk -v e="$env_events" -v t="$total_events" 'BEGIN { printf "%d", (e/t)*100+0.5 }')
    sys_pct=$(awk -v s="$sys_events" -v t="$total_events" 'BEGIN { printf "%d", (s/t)*100+0.5 }')
else
    human_pct=0; env_pct=0; sys_pct=0
fi

echo "Provenance:"
printf "  human:       %d/%d  (%d%%)\n" "$human_events" "$total_events" "$human_pct"
printf "  environment: %d/%d  (%d%%)\n" "$env_events" "$total_events" "$env_pct"
printf "  system:      %d/%d  (%d%%)\n" "$sys_events" "$total_events" "$sys_pct"
echo ""
echo "Recovery:"
printf "  Human-free recoveries: %d  (edges that went cold, then recovered without human-sourced events)\n" "$rwi_total"
printf "  Per-edge: M→S:%d  M→E:%d  S→M:%d  S→E:%d  E→M:%d  E→S:%d\n" \
    "$rwi_ms" "$rwi_me" "$rwi_sm" "$rwi_se" "$rwi_em" "$rwi_es"
echo ""

# --- Static recommendations per weak edge ---
if awk "BEGIN { exit ($weakest_val < 0.3) ? 0 : 1 }" 2>/dev/null; then
    echo "Recommendation:"
    case "$weakest_label" in
        "M→S") echo "  Memory → Structure coupling is low."
               echo "  Are structure-related corrections being captured? Check corrections.md for Triad patterns." ;;
        "M→E") echo "  Memory → Ethics coupling is low."
               echo "  Does the AI have people/context memories to calibrate ethical responses?" ;;
        "S→M") echo "  Structure → Memory coupling is low."
               echo "  Are plans guiding memory operations? Auditor should plan before memory restructuring." ;;
        "S→E") echo "  Structure → Ethics coupling is low."
               echo "  Do plans include governance criteria? Auditor review should check DN compliance." ;;
        "E→M") echo "  Ethics → Memory coupling is low."
               echo "  Is DN catching confabulation in memories? Review corrections for confab/OPSEC patterns." ;;
        "E→S") echo "  Ethics → Structure coupling is low."
               echo "  Is divergence detection finding structural drift? Check if DN flags trigger Triad correction." ;;
    esac
fi
