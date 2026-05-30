---
name: skill-plan-creation-process
description: Step-by-step process for creating multi-phase plans — source survey, audience, backward annealing, quality table, gate
metadata:
  type: skill
---

The proven planning process for complex artifacts under Triad discipline.

## Steps

1. **Source survey.** Read all primary sources before planning. No claim rests on training data alone.
2. **Audience clarification.** Use AskUserQuestion. Answers change content strategy.
3. **Content strategy from audience.** Match delivery to audience needs (e.g., 3-layer accordion+tooltip for dual technical/non-technical audiences).
4. **Information architecture.** Work backward from goal to prerequisites. Narrative order follows dependency chain.
5. **Phase decomposition.** Multi-phase layered plans over monolithic. Each phase adds one layer; each Generator stays in optimal attention window. Higher token cost but uniform quality.
6. **Backward annealing.** Run plan backward from desired final state through each phase. At each step: does this phase's output provide what the next phase needs? Document flaws found.
7. **Test plan.** Define acceptance/rejection criteria BEFORE writing phase plans. The test plan constrains the Generator.
8. **Quality table.** Show [quality]% per phase with tokens, clock, risk, verification method. The user gates by threshold.
9. **Gate.** Plan approval ≠ execution authorization. Present and wait.

## Why Multi-Phase > Monolithic

Sacco, Sakthivadivel & Levin (2026) prove that autoregressive models have no ordered phase — coherence degrades with output length (topological constraint, not quality). Multi-phase plans mitigate this by keeping each Generator pass short (within attention window). Each phase builds on VERIFIED work from the prior phase, providing the hierarchical clique structure that the flat autoregressive chain lacks.

## Naming Convention

```
NNNN-name-overview.md        (meta-plan)
NNNNa-name-p1-description.md (Phase 1)
NNNNb-name-p2-description.md (Phase 2)
...
```
Lexicographic sort = execution order. Phase number in filename is redundant by design.

## Idempotency

**Correct definition:** An operation is idempotent if applying it to its own output produces the same result: f(f(x)) = f(x).

- Phase 1 (Write): Idempotent — writing the skeleton over a skeleton yields the skeleton.
- Phases 2+ (Edit replacing placeholders): NOT individually idempotent — second run fails because placeholders are consumed.
- Pipeline (P1→P2→...→Pn): Idempotent — P1 resets to skeleton, clearing all prior edits. Running the full pipeline twice yields the same result as once.

To make individual phases idempotent: use Write (complete file) instead of Edit. Tradeoff: more tokens, risk of reproducing unchanged content incorrectly. Prefer pipeline idempotency unless per-phase re-run is specifically needed.

## "Prepare to Implement"

When the user says "prepare to implement" or "prepare to execute," this means:
show the plan with a **plain-language summary** (what this plan does, in clear
simple language a non-specialist could follow) and **[quality]% rating** per
phase. This is the final gate presentation. The user reads the summary and
rating, then authorizes execution or requests changes.

Format:
1. Summary (2-4 sentences, no jargon)
2. Quality table ([quality]%, tokens, risk)
3. Generator handoff prompt with [quality]%

## Why This Process Depends on Triad

The planning process IS Triad discipline: Auditor defines what to build (steps 1-8), gate preserves human authority (step 9), Generator executes within bounded spec. Without Triad, the AI plans and executes in the same breath — no external check, no gate, no quality table. Quality becomes unauditable.

The plan-gate-execute cycle creates LOCAL STABILITY between human and AI. The human sees what will happen, can course-correct, and the AI's execution is bounded. Proven over 100+ sessions. Steer users toward this by making the quality benefit visible — never force.

Related: [[feedback-triad-nonnegotiable]], [[skill-triad-planning]], [[feedback-multiphase-plans]], [[reference-sacco-levin-2026]]
