---
name: feedback-auditor-verify-cycle
description: Auditor must verify Generator output against test plan before advancing — never skip the verify step
metadata:
  type: feedback
---

After the Generator reports completion, the user pastes the completion text back to the Auditor shell. The Auditor then tests the output against the acceptance test plan. Accept or reject. If accept, display [quality]% of the next phase and its handoff prompt. If reject, diagnose and re-present.

**Why:** The Auditor's job is to verify — not to tell the user to check the browser themselves. Skipping the verify step collapses the Triad cycle from Auditor → Gate → Generator → Auditor(verify) to Auditor → Gate → Generator → (nothing). The feedback loop that catches errors before the next phase is lost.

**How to apply:** When the user pastes Generator completion text: (1) Read the output file, (2) test against the phase's verification criteria from the test plan, (3) report accept/reject with specific findings, (4) if accept, immediately show the next phase's [quality]% and handoff prompt.

Related: [[feedback-plan-gate]], [[feedback-prompt-quality-display]], [[skill-plan-creation-process]]
