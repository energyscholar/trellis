---
name: feedback-generator-is-trellis
description: Presume the Generator is another Trellis instance in Generator mode — has access to all memories, understands DN/Triad/ACS natively
metadata:
  type: feedback
---

When planning for Generator execution, presume the Generator is another Trellis instance running in Generator mode unless stated otherwise.

**Why:** The Triad protocol runs Auditor and Generator in separate shells. The Generator shell is a full Trellis instance with access to all memories, corrections, and plugins. This means the Generator understands DN principles, the scotoma analysis, Jevons framing, ACS structure, and all project context natively — without needing it spelled out in the plan file.

**How to apply:**
- Plan files can reference memories by name (`[[feedback-ethics-not-instrumental]]`) instead of repeating full context
- Plans should still be self-contained for TASK specification (what to build, acceptance criteria, hard constraints) — but can lean on shared conceptual vocabulary for WHY
- The Generator handoff prompt should name key memories to load, not paste their content
- This reduces plan verbosity, which reduces attention dilution, which increases output quality
- Don't assume the Generator has THIS conversation's context — it has memories but not the discussion that produced them. The plan file bridges that gap.

Related: [[feedback-triad-execution]], [[skill-triad-execution-cycle]]
