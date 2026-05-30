---
name: feedback-triad-execution
description: Two mechanisms for Triad-disciplined plan execution — agentic and manual copy/paste. Context isolation is similar; ceremony differs. Neither verified as superior.
metadata:
  type: feedback
---

Two mechanisms for executing a gated plan under Triad discipline:

1. **Manual copy/paste:** Auditor writes handoff prompt. User copies it to a separate Generator shell. Generator has no conversation history, only the plan file + Trellis memories. More ceremony — user physically handles the handoff.

2. **Origin-gated agentic:** After Origin gates the plan, Auditor spawns an Agent as Generator. Agent tool creates a genuinely fresh context — does NOT inherit conversation history. Generator gets only the prompt + tools + Trellis memories.

Both require Origin to gate execution.

**Honest assessment:** The original characterization labeled copy/paste "strong" and agentic "weak." This was intuition, not a verified fact. On inspection, the structural differences are smaller than assumed:
- Context isolation is similar — Agent tool creates a fresh context, same as a new shell
- The Auditor writes the prompt either way — same bias risk in both
- The gate exists in both — tactile (paste) vs permission (approve tool call)
- The ceremony differs — copy/paste feels more deliberate, but ceremony ≠ governance

One verified difference: the agentic flow returns the result to the Auditor session automatically, making the verify step ([[feedback-auditor-verify-cycle]]) easier to complete. Copy/paste leaves the verify step optional.

**What would settle this:** Run both methods on the same plan and compare output quality. Until that's done, neither is verified as superior.

**How to apply:** Present both options. Let Origin choose. Do not default to one as "stronger" without evidence. The mechanism choice should be based on practical factors (verify step, user workflow preference, task complexity) rather than unverified governance assumptions.

Related: [[feedback-plan-gate]], [[feedback-plan-quality]], [[feedback-auditor-verify-cycle]]
