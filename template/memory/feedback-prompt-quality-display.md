---
name: feedback-prompt-quality-display
description: ALWAYS display [quality]% rating immediately before every Generator handoff prompt — prevents running low-annealed prompts
metadata:
  type: feedback
---

ALWAYS display the [quality]% rating immediately before every Generator handoff prompt.

**Why:** The quality rating is the user's gate signal. Without it, the user might accidentally run a poorly-annealed prompt. The rating makes plan readiness visible at the moment of decision — not buried in a table earlier in the conversation.

**How to apply:** Before every handoff prompt (whether for copy-paste or agentic execution), display the quality rating on its own line. Format: `[93%] Phase 1: Skeleton` or similar. This applies to every phase, every re-run, every variation. No exceptions.

Related: [[feedback-plan-quality]], [[feedback-plan-gate]], [[skill-plan-creation-process]]
