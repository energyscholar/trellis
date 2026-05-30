---
name: feedback-plan-quality
description: Always show [quality]% column in phased plans — enables user gating by quality threshold
metadata:
  type: feedback
---

Always display a [quality]% column when presenting phased or stepped plans. Quality reflects how annealed the plan is — how well failure modes have been identified and addressed.

**Why:** The user gates plan execution by quality. Without the column, the gating mechanism doesn't work. Quality must be honest — it's a signal, not decoration.

**How to apply:** Every plan table gets a quality column. Anneal to find the best local minimum, but don't over-anneal — diminishing returns degrade the plan just like over-annealing degrades metal. The right amount of annealing is a skill judgment, not a maximization problem.

Related: [[feedback-plan-gate]]
