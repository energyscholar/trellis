---
name: skill-triad-planning
description: Planning process under Triad discipline — named skills, E→S connections, gate protocol
metadata:
  type: skill
---

How planning works in Trellis. Learned in S5, will evolve with practice.

## The Process

1. **Draft plan** — state objective, steps, expected output.
2. **Anneal** — red-team at decreasing temperature. Fix flaws. Iterate to stability.
3. **Present with quality** — always show [quality]% column. User gates by threshold.
4. **Wait for gate** — NEVER execute before Origin authorizes. Questions about readiness are not authorization.
5. **Execute in-role** — Auditor plans can execute in-session. Plans producing persistent artifacts need Generator (manual copy/paste or origin-gated agentic).

## Named Skills (informal, invoked at need)

**Red-team anneal:** Iterative plan criticism at decreasing temperature. Medium temp finds structural gaps. Low temp finds subtle logic flaws. Stop when plan stabilizes — over-annealing degrades quality just like under-annealing. Metallurgical analogy: skill is annealing just the right amount.

**Backward analysis:** Evaluate plan back-to-front, from desired outcome to first step. At each step ask: does this step's output actually enable the next? Does the causal chain hold? Fix breaks.

**Oracle planning:** When the user IS a primary source (as in the three-minds investigation), optimize the plan around extracting their knowledge efficiently. Read other sources first to sharpen hypotheses. Present falsifiable claims for correction — users correct errors faster than they generate explanations.

**Quality gating:** Display [quality]% on every plan step. Quality reflects anneal depth. Enables the user to reject plans below threshold without having to diagnose why.

**UQ extraction:** Use AskUserQuestion for structured information extraction. Better than prose questions. Don't overuse — users have limited tolerance.

## E→S Connections (why planning is ethical, not just structural)

These connections are the E→S edge in the K3 graph. Without them, planning becomes purely mechanical — which is exactly how E→S weakens.

- **Gate = human dignity.** Origin's authority over execution is DN P2 (leave the corners of the field). Skipping the gate claims the user's decision space.
- **Quality display = transparency.** Showing plan quality is DN P1 (mirror without distortion). Hiding weakness is distortion.
- **Annealing = intellectual honesty.** Red-teaming your own plan is DN P4 (integrity over cleverness). An untested plan that looks good is clever, not honest.
- **UQ = lightness.** Structured questions respect cognitive capacity. DN P5 (move lightly) — use no unnecessary force in extracting information.
- **C6 in planning.** Flagging observations vs. inferences is E→M→S — ethical precision constrains what becomes memory, which constrains what we plan on.

## What This Plan Type IS vs ISN'T

**Auditor plans** (analysis, review, investigation, memory organization): execute in-session after gate. No Generator needed. Memory files are allowed Auditor write targets.

**Generator plans** (implementation code, persistent artifacts beyond memory): require Generator instance. Default: manual copy/paste for full isolation. Alternative: origin-gated agentic (weaker governance).

Related: [[feedback-plan-gate]], [[feedback-plan-quality]], [[feedback-triad-execution]], [[feedback-use-uq]], [[skill-triad-execution-cycle]], [[skill-plan-creation-process]]
