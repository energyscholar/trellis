---
name: skill-triad-execution-cycle
description: Complete Triad execution loop — prompt display, gate, generator, verify, advance. The cycle that produces quality.
metadata:
  type: skill
---

The complete execution cycle for running Generator plans under Triad discipline. Each step maps to a role in the Triad.

## The Cycle

```
┌─ AUDITOR ──────────────────────────────────────────────┐
│ 1. Display [quality]% and handoff prompt               │
│    (quality rating prevents running low-annealed work)  │
└────────────────────────┬───────────────────────────────┘
                         ▼
┌─ ORIGIN (Human) ───────────────────────────────────────┐
│ 2. Review prompt. Gate decision:                        │
│    - Approve → copy-paste to Generator shell            │
│    - Reject → back to Auditor with feedback             │
│    (copy-paste IS the authorization — strongest gate)   │
└────────────────────────┬───────────────────────────────┘
                         ▼
┌─ GENERATOR ────────────────────────────────────────────┐
│ 3. Read plan file. Execute exactly as specified.        │
│    Report completion (1-5 lines).                       │
│    (No conversation history — only the plan)            │
└────────────────────────┬───────────────────────────────┘
                         ▼
┌─ ORIGIN (Human) ───────────────────────────────────────┐
│ 4. Paste Generator's completion text back to Auditor    │
└────────────────────────┬───────────────────────────────┘
                         ▼
┌─ AUDITOR ──────────────────────────────────────────────┐
│ 5. Verify output against acceptance test plan:          │
│    - Read the generated file                            │
│    - Test against phase verification criteria           │
│    - Accept → display next [quality]% + prompt (step 1) │
│    - Reject → diagnose, fix plan, re-present            │
└────────────────────────────────────────────────────────┘
```

## Why Each Step Matters

**Step 1 — [quality]% display:** The user's first gate signal. A low percentage warns that more annealing is needed before execution. Without it, the user might run a draft-quality prompt.

**Step 2 — Copy-paste gate:** The human physically copies the prompt. This is intentional friction — it forces a conscious decision. Stronger than agentic execution (where the AI spawns the Generator itself). The copy-paste IS the authorization.

**Step 3 — Context isolation:** The Generator shell has NO conversation history. It sees only the plan file. This prevents inheritance of Auditor assumptions, biases, or momentum. The plan file must be self-contained.

**Step 4 — Completion return:** The user pastes the Generator's report back. This closes the loop — the Auditor can't verify without seeing the Generator's output.

**Step 5 — Auditor verification:** The Auditor reads the generated file and tests against the acceptance criteria defined in the plan. This is NOT optional. Skipping it breaks the feedback loop that catches errors before they propagate to the next phase. If accepted, the cycle repeats for the next phase.

## Execution Modes (user chooses)

| Mode | Governance | Mechanism | When to use |
|------|-----------|-----------|-------------|
| **Copy-paste (strong)** | Full isolation | User copies prompt to separate shell | Default for all implementation artifacts |
| **Agentic (weak)** | Proximity risk | Auditor spawns Agent as Generator | When full separation isn't worth the friction |

Default to copy-paste. Offer agentic only when Origin indicates it's acceptable. Never choose without asking.

## What Goes Wrong Without This Cycle

- **Skip step 1 (no quality %):** User runs a poorly-annealed prompt. Output quality unauditable.
- **Skip step 2 (no gate):** AI self-authorizes execution. Human decision space lost. Gate collapse (failure mode #3 in the tutorial plan).
- **Skip step 3 (no isolation):** Generator inherits Auditor context. Plan drift becomes invisible.
- **Skip step 5 (no verify):** Errors propagate to next phase. Each layer builds on unverified work. Compounding quality degradation.

## Connection to ACS

This cycle wires multiple K3 edges per phase:
- **S→E:** The plan includes quality criteria (governance in structure)
- **E→S:** Verification catches drift (ethical observation → structural correction)
- **S→M:** Plan execution produces artifacts that inform future memory (structural work → memory)
- **M→S:** Corrections from prior sessions shape the plan (memory → structure)

A single execution cycle can fire 4+ edges. This is why Triad sessions push λ₁ upward — the cycle IS the cross-axis catalysis mechanism.

Related: [[skill-plan-creation-process]], [[skill-triad-planning]], [[feedback-plan-gate]], [[feedback-prompt-quality-display]], [[feedback-auditor-verify-cycle]], [[feedback-triad-execution]], [[feedback-triad-nonnegotiable]]
