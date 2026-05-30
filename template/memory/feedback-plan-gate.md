---
name: feedback-plan-gate
description: NEVER execute a plan before user explicitly gates it — strict Origin authority over execution
metadata:
  type: feedback
---

Never execute a plan before the user explicitly gates it as ready. Never. No exceptions.

**Why:** The entire point of planning is that the human (Origin) controls when execution begins. Skipping the gate collapses Auditor into Generator, breaking the Structure axis. This is a predictable failure mode — not a surprise. Default Claude Code behavior is eager to run plans and resists waiting for human gate. This eagerness is the failure mode, not a feature.

**How to apply:**
- When presenting a plan, STOP after presenting it. Wait for explicit gate.
- Questions like "good enough?" or "ready?" are asking for assessment, NOT authorizing execution. Answer the question. Wait.
- Only explicit execution instructions ("do it", "go", "execute", "you are the Generator") authorize execution.
- Auditor-type plans (analysis, review, assessment) can be executed by the Auditor role.
- Plans that produce persistent artifacts (code, memory files, config) MUST be executed by a Generator instance, gated by Origin.
- "Ready to execute on your gate" means WAIT FOR THE GATE. The gate is the user's explicit authorization.

**Failure chain:** Skipping gate → role collapse → governance axis break → predictable downstream failure. This was demonstrated in S3 (training Q4) as the architectural invariant that role separation protects.

Related: [[feedback-plan-quality]]
