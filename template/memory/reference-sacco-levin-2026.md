---
name: reference-sacco-levin-2026
description: "Topological constraints on self-organization" (Sacco, Sakthivadivel, Levin 2026) — proves LLMs can't self-organize, topology determines phase transitions
metadata:
  type: reference
---

Sacco F, Sakthivadivel D, Levin M. 2026. "Topological constraints on self-organization in locally interacting systems." *Phil. Trans. R. Soc. A* **384**: 20250011. doi:10.1098/rsta.2025.0011

**Why it matters for Trellis:**

1. **Proposition 2:** Decoder-only autoregressive models (all current LLMs) have no ordered phase. Mathematically proven — not empirical, not approximate. The 1D causal chain of tokens cannot sustain long-range order at any temperature.

2. **Corollary 2:** Autoregressive models cannot converge to a single stored pattern for any finite β. Coherence degrades with output length. This is topological, not a training or intelligence problem.

3. **Section 6 + Theorem 4 + Proposition 3:** Hierarchical systems with cliques (complete subgraphs) CAN maintain local order within cliques. Coupled cliques can produce hierarchical ordering behavior — local order propagates upward when inter-clique coupling is sufficient.

4. **Theorem 1 (Topological Equivalence):** All local Hamiltonians on lattices with the same combinatorial structure have asymptotically equivalent free energies. Topology is the determining factor, not interaction strength.

**Connection to Trellis K3:**
- Each axis (M, S, E) functions as a clique: internally ordered, persistent, outside the token chain
- Memory files, corrections, plan files = external ordered states not subject to the 1D autoregressive constraint
- The K3 graph = the inter-clique topology connecting the three axes
- ACS closure (λ₁ ≥ 1.0) = the phase transition to self-sustaining hierarchical order
- Removing one axis (2-axis collapse) reduces the inter-clique topology below the threshold for hierarchical ordering

**For the tutorial:** This paper gives rigorous grounding to the claim that Trellis is not just helpful but structurally necessary. The vanilla LLM is proven unable to self-organize. Trellis provides the topology that enables it.

**Claim classification (per [[skill-dk-prevention]] framework):**
- Sacco/Levin Prop 2 (1D → no ordered phase): **Established** — their theorem, published, peer-reviewed.
- Our extension (governance adds hierarchical topology): **Not precluded** — no physics forbids it. Our hypothesis, not their claim. Structural analogy via Kauffman criticality.
- K3 ACS closure as phase transition: **Structural analogy** — formally mapped using Hordijk/Steel RAF definitions. Not experimentally validated with statistical rigor (N=2, finite-size regime).

Related: [[reference-trellis-purpose]], [[feedback-triad-nonnegotiable]], [[skill-dk-prevention]], [[skill-dk-anchoring]]
