---
name: skill-dk-prevention
description: Evaluation framework for cross-domain claims — precluded/not-precluded/not-in-domain + D-K error pattern at domain boundaries
metadata:
  type: skill
---

## Evaluation Framework

Three categories for evaluating claims that cross domain boundaries:

- **Precluded** = a specific law, theorem, or established result prohibits it. Name the source.
- **Not precluded** = no known result prohibits it. May be undemonstrated, unlikely, or require stacking speculative steps — but the domain does not forbid it.
- **Not a domain claim** = narrative, strategic, or philosophical content outside the domain's scope.

"Not precluded" is weaker than "plausible," and much weaker than "supported." A scenario requiring many speculative steps is not thereby precluded. This standard blocks lazy dismissals without validating speculation.

## D-K Error Pattern at Domain Boundaries

LLMs (and domain experts) exhibit Dunning-Kruger effects at domain boundaries: confident dismissals based on incomplete knowledge. The pattern:

1. System knows Domain A well, knows Domain B well
2. The INTERSECTION of A and B contains specialized knowledge absent from training data
3. System substitutes familiar A-only or B-only knowledge for the intersection
4. Result: plausible but wrong conclusions, delivered with high confidence

## How to Apply

When evaluating claims that cross domain boundaries:

1. **Identify the boundary.** Which domains intersect?
2. **Check for substitution.** Is the reasoning using Domain A's framework where the intersection's framework applies?
3. **Apply the framework.** Is the claim precluded, not precluded, or not a domain claim? If "precluded," NAME THE SOURCE. If you can't name it, it's not precluded.
4. **Anchor to published results.** Claims touching established domains should cite specific results. Classify each anchor: Established (published, uncontroversial), Qualified (correct but narrower than it appears), Structural analogy (formal mapping, not proven equivalence).

## Harm Prevention

D-K errors at domain boundaries cause real harm: confident, authoritative-sounding dismissals that are wrong at a specific intersection where the correct knowledge is absent from standard training. The remedy is anchoring claims to specific published results and explicitly classifying the anchor type.

Related: [[reference-sacco-levin-2026]]
