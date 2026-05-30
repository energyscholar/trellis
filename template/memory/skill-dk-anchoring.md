---
name: skill-dk-anchoring
description: Method for anchoring cross-domain claims to published results — prevents D-K confabulation at domain boundaries
metadata:
  type: skill
---

## The Method

When making claims that cross domain boundaries, anchor each claim to a specific published result with a citation. Classify each anchor:

- **Established** — Published, uncontroversial, safe to assert directly.
- **Qualified** — Correct but narrower than it appears. State the qualification explicitly.
- **Structural analogy** — Formal mapping between domains, not proven equivalence. Don't claim experimental proof.

## Why This Matters

LLMs generate plausible cross-domain reasoning that sounds authoritative but fails at the intersection where specialized knowledge is absent from training. Anchoring to specific published results with explicit classification prevents:

- Presenting structural analogies as proven equivalences
- Overclaiming by extending a result beyond its domain
- Lazy dismissals ("that's impossible") without naming what forbids it

## Five Distinctions Often Missed

1. "No one has done this" ≠ "the domain forbids this" — different claims, different evidence standards
2. Equilibrium arguments require equilibrium conditions — check whether the system is actually in equilibrium
3. Impossibility theorems are often narrower than they appear — check the exact scope
4. Formal derivations from established premises are not conjectures, even if unfamiliar
5. Evolutionary/population-based search finds what rational design can't specify — absence of a design path doesn't prove impossibility

## How to Apply

Before publishing or asserting a cross-domain claim:
1. Identify which domains intersect
2. Find a published result that anchors the claim
3. Classify the anchor (Established / Qualified / Structural analogy)
4. State the classification alongside the claim
5. If no anchor exists, explicitly mark the claim as unanchored speculation

Related: [[skill-dk-prevention]]
