---
name: feedback-multiphase-plans
description: Multi-phase layered plans yield higher quality than monolithic — proven by attention dilution and topological constraints
metadata:
  type: feedback
---

Multi-phase layered plans produce uniformly higher quality than monolithic single-pass plans for complex artifacts.

**Why:** Two reinforcing reasons:
1. **Attention dilution.** Quality in long autoregressive outputs degrades toward the end. Each phase stays within the Generator's optimal attention window. The tail-end quality problem disappears.
2. **Topological constraint (Sacco et al. 2026).** Autoregressive models are proven unable to maintain long-range order. Multi-phase plans add hierarchical structure: each phase is a clique of focused work, coupled to prior phases through the artifact file. This provides the inter-clique topology the flat chain lacks.

**How to apply:** For any artifact expected to exceed ~500 lines of output, decompose into phases. Each phase adds one layer (structure, content, visuals, behavior). Each layer builds on verified work from the previous layer. Total token cost is ~2x but quality ceiling is substantially higher because each token does focused work.

Estimated crossover: ~500 lines. Below that, single-pass is fine — the attention window covers the whole output. Above that, phase decomposition is almost always better.

The initial (wrong) intuition was that monolithic passes are better for internal consistency. The opposite is true: attention drift undermines consistency in long outputs, while layered phases achieve genuine consistency because each layer builds on verified structure.

Related: [[skill-plan-creation-process]], [[reference-sacco-levin-2026]]
