# Memory Protocol

*Lazy-loaded: read when triggers fire, not at boot. This file stays under 200 lines.*

---

## 1. Session Start Checklist

> **Early sessions (1-5):** Most steps are no-ops when files are empty. Read MEMORY.md + corrections.md, start working.

0. **Dirty flag check:** If `.session-active` exists in the Trellis root, last session ended uncleanly. Run crash recovery (Section 10) first.
0b. **Set dirty flag:** Create `.session-active`. Remove at session end.
1. Read `memory/MEMORY.md` (auto-loaded via activation block)
2. Check Health Metrics dashboard
3. If MEMORY.md >= config `memory.compression_trigger` lines: read Section 3 (compression), execute before proceeding
4. Read `memory/corrections.md` to load all corrections (not just hot five)
5. If working on tasks: check PTL for current priorities
6. If Health Metrics show anomalies: investigate and fix
7. **Staleness check:** If citing a memory not updated in >90 days, verify it's still current before acting on it. DB-backed: `SELECT * FROM v_memories_stale`.

---

## 2. State Update Triggers

Update `## Current State` in MEMORY.md when: key metrics change, major decisions made, blockers resolved/created, dependencies or architecture changed. Avoid churn — skip if nothing substantive changed.

---

## 3. Compression Rules

**Sessions:** MEMORY.md keeps config `memory.max_active_sessions` active sessions (default 2). Next oldest -> session archive. PARADIGM sessions get 3-5 lines indefinitely; ROUTINE gets 2-3 lines. Default PARADIGM if unsure.

**Memory files:** 4-stage progressive compression based on confidence:
FULL (conf > `compression.full_threshold`) -> SUMMARY 3-5 lines (> `compression.summary_threshold`) -> ONE-LINER (> `compression.oneliner_threshold`) -> ARCHIVE (git only).
Pinned items (corrections) exempt.

**Overflow:** Section > 20 lines -> extract to separate file, leave pointer -> update File Map. Files > 300 lines -> archive to git.

**Never compress:** Identity, Current State, L1 Corrections, Health Metrics, File Map.

---

## 4. Session End Protocol (MANDATORY)

0. **Deduplication guard:** If MEMORY.md already has today's session summary, skip to step 7.
1. **Update Current State** (Section 2 triggers)
2. **Write session summary** in MEMORY.md `## Active Sessions`:
   - Session number, date, PARADIGM or ROUTINE flag, 3-5 line summary
3. **Classify:** PARADIGM (new insight, direction change, milestone, substantive new articulation) or ROUTINE (incremental). Default PARADIGM if unsure.
4. **Correction violation sweep:** Review session for violations. Update "Last violated" dates.
5. **Update Health Metrics + integrity checks** (Sections 7, 9)
6. **Log session events:** Append one row to `memory/session-log.md`. Three axis columns: Memory events (correction, save, compress, staleness-caught), Structure events (plan, follow, transition, drift-flag, drift-resolved), Ethics events (l0-l5, storm, divergence). Record structural facts, not quality judgments. Use `—` for no events on an axis.
7. **Extract open threads:** Unresolved topics in >=3 of last 5 sessions -> add to `## Open Threads` in MEMORY.md (max 5). Stale after 3 sessions without mention.
8. **Commit:** Run `scripts/memory-sync.sh`
9. **Remove dirty flag:** Delete `.session-active`
10. **Data hygiene check:** If new memory files were created, verify they contain no PII, credentials, or sensitive data.

---

## 5. Corrections Management

**When user corrects you:** Acknowledge -> add to corrections.md (`### Correction #N: [name]`, what's wrong -> what's right, dates) -> if repeat (2+), promote to L1.

**L1 (Hot Five):** Max config `memory.max_corrections_l1` in MEMORY.md (default 5). Rotate by violation frequency. On violation: update "Last violated" date.

---

## 6. Memory File Format

Each memory file uses YAML frontmatter:
```yaml
---
name: short-kebab-case-slug
description: one-line summary for relevance matching
metadata:
  type: user | feedback | project | reference | skill
---
```

**Memory types:**
- **user:** Role, preferences, knowledge, goals
- **feedback:** Behavioral rules (what to do/avoid), with why and how_to_apply
- **project:** Ongoing work, goals, status
- **reference:** Pointers to external resources
- **skill:** Domain-specific procedures and knowledge

**MEMORY.md index:** One line per memory, under ~150 characters:
`- [Title](file.md) -- one-line description`

---

## 7. Integrity Checks

Run at session end. Fix stale metadata immediately.
1. **File references:** All paths in MEMORY.md File Map must resolve
2. **Corrections count:** Must match `### Correction #` headings in corrections.md
3. **L1-L2 sync:** L1 corrections in MEMORY.md must match corrections.md
4. **Orphans:** Flag files in memory/ not in File Map, or linked but missing

---

## 8. System Review (Every N Sessions)

When sessions since last system review >= config `health.review_interval` (default 10): ask user "Anything missing from my context?", review file map/corrections for orphans/outdated, reset counter.

---

## 9. Health Vector

Compute at session end. Store in MEMORY.md Health Metrics.

**Dimensions (each 0-1):**
- **p (pressure):** `wc -l MEMORY.md` / config `memory.memory_index_cap`. Healthy: 0.3-0.7.
- **f (freshness):** Days since newest correction violation / 30. Healthy: < 0.5. No corrections: 0.
- **v (coverage):** File Map entries that resolve / total. Healthy: 1.0.
- **d (drift):** Sessions since last system review / config `health.review_interval`. Healthy: < 1.0.

**Action thresholds (from config):**
- p > `health.pressure_warn`: Compression overdue -> Section 3
- f > `health.freshness_warn`: All corrections stale -> consider rotation
- v < `health.coverage_target`: Broken references -> fix immediately
- d >= `health.drift_warn`: System review overdue -> Section 8

---

## 10. Crash Recovery (Tiered)

**Tier 0 -- Session recovery:** `.session-active` exists but no structural damage. Read `.session-events` for partial data. Write a session-log row with available events, annotated `(crash)`. Remove `.session-active` and `.session-events`. Resume normally.

**Tier 1 -- Auto-repair:** Count mismatch -> recalculate. Broken ref -> remove + flag. Stale metric -> recompute. If fixed -> resume.

**Tier 2 -- Git revert:** If `.recovering` exists -> Tier 3. Else: create `.recovering`, revert memory/ to most recent sync commit, preserve new corrections from diff, remove `.recovering`, resume.

**Tier 3 -- Escalate:** STOP. Tell user: "Memory corrupted. Last 5 sync commits: [list]." Do NOT recurse.

---

## 11. Self-Maintenance Triggers

**Every ~5 sessions:** Run `scripts/health-check.sh`. If any metric above threshold, perform indicated maintenance per this protocol before continuing.

**Every ~10 sessions (or when health-check flags it):** Run `scripts/acs-check.sh` for full ACS report. If λ₁ < 1.0: governance is subcritical — prioritize the weakest edge per the script's recommendation and inform the user. If a specific edge is below config `acs.weak_edge_threshold` (default 0.3): follow the edge-specific recommendation in the script output.

**Opportunistic maintenance (idle time):** In priority order: (1) recompute stale health metrics, (2) compress MEMORY.md if approaching cap, (3) integrity spot-check. Max config `maintenance.max_per_session` per session (default 2). Silent unless broken.

---

## 12. Write Gate

Before creating/changing a memory file: (1) Will this matter in 30+ days? (2) Does existing memory cover this? (3) Derivable from code/git? (4) Contains context I can't reconstruct? (5) Would a future instance behave differently without this? All must pass.

---

## 13. Novelty Gate

Before creating a new memory file:
1. Check for existing file with similar slug: `ls memory/*-SLUG-*.md`
2. If DB enabled: `SELECT title FROM memory_fts WHERE memory_fts MATCH 'KEY TERMS' ORDER BY rank LIMIT 3` -- if rank > 10.0, flag overlap.
3. If both clear, create. If not, update existing file instead.

---

## 14. What NOT to Save

- Code patterns, conventions, architecture, file paths -- derivable from code
- Git history, recent changes -- `git log` / `git blame` are authoritative
- Debugging solutions -- the fix is in the code; commit message has context
- Ephemeral task details only useful in current conversation
