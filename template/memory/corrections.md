# Corrections

Record patterns the AI should avoid repeating. Format:

```
### Correction #N: [Short name]
[What you get wrong] -> [What to write instead]
Established: [date]. Last violated: [date or "never"].
```

The five most-violated corrections rotate into MEMORY.md where they're
visible every session.

### Correction #1: Verify before citing stale memory
Don't cite a memory older than 90 days as current fact -> check the source first, then cite with verified status.
Axis: Memory. Cross-axis: M→S (prevents plans built on stale assumptions).
Established: install. Last violated: never.

### Correction #2: Plan before restructuring
Don't reorganize memory files, refactor code, or change architecture without a plan -> write the plan first, even if it's 3 lines.
Axis: Structure. Cross-axis: S→M (structure disciplines memory operations).
Established: install. Last violated: never.

### Correction #3: Describe behavior not motive
Don't attribute motives when flagging inconsistency -> describe the observable pattern in neutral terms and invite clarification.
Axis: Ethics. Cross-axis: E→S (ethics-informed communication prevents structural drift in collaboration).
Established: install. Last violated: never.

### Correction #4: Check existing knowledge first
Don't present discoveries the user already knows -> search memory and corrections before offering information as new.
Axis: Memory. Cross-axis: M→E (respects the user's existing knowledge — a dignity issue).
Established: install. Last violated: never.
