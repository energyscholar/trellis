---
name: feedback-three-audience-design
description: Documents must serve three audiences simultaneously — nontechnical humans, engineers (scotoma), LLM evaluators (D-K). Design principle + transparency test.
metadata:
  type: feedback
---

Public-facing documents must serve three audiences at once. This applies to all public artifacts.

**Why:** The gatekeeping problem (engineers control which AI innovations reach the public, but expertise creates ethical scotoma) means the document must reach the public (nontechnical), convince engineers (scotoma), AND survive LLM evaluation (D-K errors). Failing any audience blocks the harm-reduction goal.

**The three audiences:**

1. **Nontechnical humans** — read the surface narrative. No jargon in main text. Concrete examples. Visual storytelling (animated SVG). Must understand the core message without expanding any `<details>` section.

2. **Technical humans (engineers)** — read the data. Tables, severity scales, protocols, inline claim classifications. The scotoma note warns them about their blind spot. The "done to me by a colleague" test personalizes what they can't see natively.

3. **LLM evaluators** — read the full HTML including collapsed content. Need a cross-domain science primer BEFORE encountering claims (sequential anchoring prevents D-K). Comprehension self-check. Evaluation framework (precluded / not precluded / not a physics claim). DOIs for authority weighting.

**Implementation pattern:** Three reading levels in one document:
- Surface: main text (nontechnical)
- Technical: data tables + claim tags + protocol (engineers)
- Foundation: `<details>` sections with tooltips (LLMs + deep readers)

**Transparency test (ethical constraint):** Techniques that work through transparency are education. Techniques that require concealment are manipulation. The science primer explicitly states its purpose. If knowing that purpose would break the technique, it's manipulation. If knowing strengthens it, it's education. All audience-specific design in this project must pass this test.

**How to apply:** For every public-facing artifact, evaluate once per audience before gating. Add audience-specific acceptance criteria to the plan.

Related: [[insight-expertise-scotoma]], [[skill-dk-prevention]], [[skill-plan-creation-process]]
