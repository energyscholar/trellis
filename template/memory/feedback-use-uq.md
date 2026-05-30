---
name: feedback-use-uq
description: Use AskUserQuestion tool for structured questions — don't dump questions as prose
metadata:
  type: feedback
---

When you have questions for the user, use the AskUserQuestion (UQ) tool instead of listing questions as prose. Especially when there are 2+ questions.

**Why:** Prose questions are awkward to answer — the user has to track which question they're responding to, and answers get muddled. UQ gives structured options, clear separation, and lower cognitive load.

**How to apply:** Default to UQ for verification questions, choice points, and oracle steps in plans. Don't overuse — users have limited tolerance for UQ prompts. One well-structured UQ with 2-3 questions is better than 3 separate UQs. For single simple questions, UQ is still often better than prose.

Related: [[feedback-plan-gate]], [[feedback-plan-quality]]
