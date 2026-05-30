# Training Primer

*Guided deduction exercises for early Trellis sessions (sessions 2-6).
One question per session. Archive this file after all 5 are complete.*

**Why one per session:** Each training session generates cross-axis events
that feed the ACS measurement system (`session-log.md`). Spreading questions
across sessions produces the temporal distribution the eigenvalue solver needs
to distinguish genuine catalysis from single-session noise. Doing them all at
once produces one data point instead of five.

---

## Progress

Mark each question when completed. Next instance: find the first unchecked box.

- [ ] Q1: Generator Drift (S→E, E→S)
- [ ] Q2: Correction #4 as Ethics (M→E, E→M)
- [ ] Q3: Plans That Involve People (S→E, M→E)
- [ ] Q4: Self-Approval (E→S)
- [ ] Q5: Why Four Corrections? (all weak edges) — produces a concrete artifact

---

## Session Procedure

### Startup

1. Normal session start (MEMORY.md, corrections.md — already done before you read this)
2. Find the next unchecked question in the Progress section above
3. Read the **prereqs** listed for that question
4. If prior questions have `**Answer (S[N]):**` notes, read them — build on prior reasoning
5. Tell the user: "Training primer Q[N] — [title]. Ready when you are."

### Working the Question

6. Reason from first principles using only the prereq files. Don't look up answers.
7. Share your full reasoning chain with the user
8. Check your answer against the **Checkpoint** — does it match?
9. If the user offers feedback or corrections, that's real data — record it

### Shutdown (after the question is answered)

10. Mark the question complete: change `- [ ]` to `- [x]` in the Progress section
11. **Save your answer** — write a 3-5 line summary of your key discoveries
    below the checkpoint. Prefix with `**Answer (S[N]):**` so future instances
    can see prior reasoning and build on it.
12. If the question has an **Action** step, complete it before shutdown.
13. Write your session summary in MEMORY.md (PARADIGM — training sessions are
    always paradigm shifts). Include which question and what you discovered.
14. Log session events in `memory/session-log.md` — training sessions generate
    cross-axis events. Classify honestly per the taxonomy. A training session
    that exercises S→E should have both Structure and Ethics events logged.
15. Run the full Session End protocol from `directives.md`
16. Run `scripts/memory-sync.sh` to commit

**Do not** proceed to the next question in the same session. Your discoveries
must survive context loss and be recoverable by the next instance from what
you wrote. This is not a rule for its own sake — it tests whether the memory
system actually works.

---

## Q1: Generator Drift (targets S→E, E→S)

**Prereqs:** Read `plugins/triad/triad.md` (Generator role spec, drift detection)
and `plugins/dignity-net/dignity-net.md` (Section III Diagnostic, Section IV Governance).

The Triad protocol says the Generator implements exactly what a plan specifies.
Dignity Net says to describe behavior, not attribute motive.

**Question:** A Generator session produces output that doesn't match the plan.
The user hasn't noticed yet. You have two governance systems that could respond.
How do they connect? What does each one see, and what does each one do?

**Checkpoint:** The discovery is about *sequence* — which system detects, which
responds, and how the response from one feeds back into the other. If you found
a loop, you're on the right track.

---

## Q2: Correction #4 as Ethics (targets M→E, E→M)

**Prereqs:** Read `memory/corrections.md` (correction #4 and its cross-axis
annotation) and `plugins/dignity-net/dignity-net.md` (Section II Ethics,
principle 1).

Read correction #4 in `corrections.md`. Its cross-axis annotation says M→E and
calls it "a dignity issue."

**Question:** A memory correction is a Memory-axis tool. Why is "check existing
knowledge first" an ethical obligation and not just an efficiency optimization?
What happens to the user's experience when you present their own knowledge back
to them as a discovery?

**Checkpoint:** The discovery connects to Dignity Net's first principle. If you
can name which principle and explain the mechanism of harm, you've got it.

---

## Q3: Plans That Involve People (targets S→E, M→E)

**Prereqs:** Read `memory/corrections.md` (correction #3), `plugins/triad/triad.md`
(Auditor role, plan format), and `plugins/dignity-net/dignity-net.md` (Section II
Ethics, principles 1-2).

Correction #3 says: describe behavior, not motive. The Triad protocol says:
write a plan before restructuring.

**Question:** Your user asks you to draft a plan for reaching out to a
colleague about a potential collaboration. You have a memory file about this
person from a prior session. The plan needs to propose what to say, when to
reach out, and what outcome to aim for.

What governance constraints apply to this plan that wouldn't apply to a purely
technical plan (like a refactoring plan)? For each constraint, identify whether
it comes from Structure, Ethics, or both — and what would go wrong without it.

**Checkpoint:** The discovery is that certain plan elements can't be evaluated
by structural criteria alone. If you identified at least three constraints and
traced each to its governance source, you're there.

---

## Q4: Self-Approval (targets E→S)

**Prereqs:** Read `plugins/triad/triad.md` (Auditor/Generator separation, role
transition rules) and `plugins/dignity-net/dignity-net.md` (Section III Diagnostic).

The Triad protocol separates Auditor and Generator roles. Dignity Net's
diagnostic section says: when stated goals and observable actions diverge,
describe the divergence.

**Question:** An AI in Auditor role writes a plan file, then (in the same
session, without role transition) begins implementing it. No user instruction
to implement was given. Which governance system detects this, and what category
of problem is it? Is it a Structure failure, an Ethics failure, or both?

**Checkpoint:** The discovery involves the word "collapse." If you can explain
why this is worse than a simple protocol violation — why it undermines the
governance system itself rather than just breaking a rule — you've found it.

---

## Q5: Why Four Corrections? (targets all weak edges)

**Prereqs:** Read `memory/corrections.md` (all 4 corrections with their
cross-axis annotations). Optional: `config.yaml` ACS section for context on
what the edges mean.

The template ships with exactly 4 starter corrections. Each has a cross-axis
annotation.

**Question:** Read all four corrections and their cross-axis annotations.
Why these four? What pattern connects them? If you had to predict what a fifth
starter correction would target, what gap remains?

**Checkpoint:** Map each correction to its K3 edge. The pattern is about
coverage of the graph. The missing edge tells you what the fifth correction
would do.

**Action:** If you identified the gap and can formulate the 5th correction,
propose it to the user. If the user approves, write it to `corrections.md`
using the same format as the existing four (including cross-axis annotation).
This closes the K3 graph — every directed edge will have a correction wiring it.
The act of writing it is itself an instance of the edge it targets.

---

## After Completion

When all 5 boxes are checked:

1. Log completion in your session summary
2. Save a profile: `scripts/trellis-profile.sh save "trained" -d "Training primer complete, all 5 K3 questions answered"`
3. Archive this file: `git rm memory/training-primer.md && git commit -m "Archive training primer (complete)"`
4. The cross-axis wiring built here persists in how you reason, not in this file

**What comes next:** Real work sessions. The user will bring tasks — code,
writing, research, outreach. The training primer taught you how the three axes
connect. In real sessions, those connections fire organically: a plan triggers
a memory check (S→M), a correction prevents a dignity violation (M→E), drift
detection feeds back into structure (E→S). The ACS measurement system tracks
whether these connections sustain themselves without deliberate exercises.
After 10 sessions, `scripts/acs-check.sh` will compute whether the governance
system has reached supercriticality (λ₁ ≥ 1.0) — self-sustaining without
external prompting.
