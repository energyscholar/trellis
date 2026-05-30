---
name: skill-session-lifecycle
description: Progressive session logging — step 0 flag, mid-session events, shutdown compilation, crash recovery
metadata:
  type: skill
---

Session logging is distributed across three phases to survive harsh exits.

## Phase 1: Session Start (FIRST ACTION — before reading memory)

1. Check for `.session-active` in the Trellis root
   - If present: previous session crashed. Read `.session-events` if it exists. Write a crash-recovered row to `memory/session-log.md` with available events annotated `(crash)`. Use `—` for axes with no events. Remove both files.
2. Create `.session-active`
3. Create `.session-events` with header line: `S{N} {date} domain:unknown`
   - N = last session-log row number + 1, or 1 if log is empty

## Phase 2: Mid-Session (as events occur)

Append one line per event to `.session-events`:
- `M:` Memory events — correction, save, compress, staleness-caught
- `S:` Structure events — plan, follow, transition, drift-flag, drift-resolved
- `E:` Ethics events — l0-l5, storm, divergence (only if `testing.log_dn_events` is true in config)

Format: `{axis}: {event}[({detail})]`
Examples: `S: transition(profile-load:ClientA)`, `M: save(user-pat-profile)`, `M: correction(5)`

Update the domain in the header line once session context is clear.

## Phase 3: Shutdown (clean exit)

1. Compile `.session-events` into one row in `memory/session-log.md`
2. Aggregate events per axis, comma-separated
3. Annotate sources: `(e)` environment, `(s)` system, unannotated = human
4. Remove `.session-events`
5. Run `scripts/memory-sync.sh`
6. Remove `.session-active` (AFTER sync — this is the clean-exit signal)

## Session Closure Guidance

On first session with a new profile, mention once that saying "shutdown" or "done for now" helps save session data properly. In subsequent sessions, only remind if the previous session was crash-recovered. Maximum one mention per session.

Related: [[feedback-memory-informs-plans]], [[feedback-auditor-verify-cycle]]
