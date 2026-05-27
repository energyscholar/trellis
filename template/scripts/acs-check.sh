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
acs_min_sessions=$(get_config "acs_min_sessions" "10")
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

read -r m_activity s_activity e_activity \
       m_to_s m_to_e s_to_m s_to_e e_to_m e_to_s <<< "$(echo "$windowed" | awk -F'|' '
BEGIN { n=0; ma=0; sa=0; ea=0; ms=0; me=0; sm=0; se=0; em=0; es=0 }
{
    n++
    mem = $4; str = $5; eth = $6

    # Per-axis activity (any non-trivial event)
    has_m = (mem !~ /^[-—]?$/ && mem != "")
    has_s = (str !~ /^[-—]?$/ && str != "")
    has_e = (eth !~ /^[-—]?$/ && eth != "" && eth !~ /^l0$/)

    if (has_m) ma++
    if (has_s) sa++
    if (has_e) ea++

    # Atomic event flags
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

    # Cross-axis catalysis (co-occurrence)
    if (m_correction && (s_drift_res || s_follow))  ms++
    if ((m_correction || m_save) && (e_l1plus || e_divergence))  me++
    if (s_plan && (m_compress || m_save))  sm++
    if ((s_plan || s_follow) && e_l0_only)  se++
    if ((e_l1plus || e_divergence) && m_correction)  em++
    if (e_divergence && (s_drift_flag || s_drift_res))  es++
}
END {
    if (n == 0) n = 1
    printf "%.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f\n", \
        ma/n, sa/n, ea/n, ms/n, me/n, sm/n, se/n, em/n, es/n
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

# --- One-liner mode (for health-check integration) ---
if [ "$oneliner" = "--oneliner" ]; then
    printf "  acs:           λ=%.2f gap=%.2f weak=%s(%.2f) [%s]\n" \
        "$lambda1" "$spectral_gap" "$weakest_label" "$weakest_val" "$status"
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
