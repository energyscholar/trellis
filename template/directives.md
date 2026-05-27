# Trellis Directives

## Memory System

You have a persistent memory directory at `memory/`. Its contents persist across conversations.

### File Structure

- `memory/MEMORY.md` -- Always in context. Identity, current state, hot corrections, active sessions, health metrics, file map. Hard cap from config `memory.memory_index_cap` (default 200 lines).
- `memory/corrections.md` -- Things you consistently get wrong. Short imperatives.
- `memory/protocol.md` -- Session lifecycle: start checklist, end checklist, compression rules, integrity checks. Read when triggers fire.
- Other `memory/*.md` files -- Individual memories loaded on demand.

### Session Start

1. Read `memory/MEMORY.md` (auto-loaded)
2. Read `memory/corrections.md` -- check every correction
3. If MEMORY.md is near the line cap: read `memory/protocol.md` Section 3, compress
4. Check health metrics; if anomalies, investigate
5. After 5+ sessions: run `scripts/health-check.sh` every ~5 sessions
6. **Staleness check:** Before citing any memory not updated in >90 days, verify it's still current.

### Session End

1. Update current state in MEMORY.md
2. Write session summary (classify as PARADIGM or ROUTINE, include date)
3. Correction violation sweep: review session for violations, update dates
4. Run integrity checks (verify file paths, correction count, orphans)
5. Update health metrics
6. **Log session events:** Append one row to `memory/session-log.md` — classify which events fired per axis this session (Memory/Structure/Ethics columns). Record structural facts only, not judgments about quality.
7. Run `scripts/memory-sync.sh` to commit memory files
8. Remove `.session-active` flag
9. If new memory files created: verify no PII or credentials

### Saving Memories

**When to save:** User corrections, behavioral feedback, project context, external references, people details. Apply write gate: will this matter in 30+ days? Does existing memory cover it? Derivable from code/git?

**File format:** YAML frontmatter with name, description, type. Body content. One line per file in MEMORY.md index.

**Types:** user (role/preferences), feedback (rules with why + how_to_apply), project (goals/status), reference (external resources), skill (procedures).

### Self-Maintenance

Triggers:
- MEMORY.md approaching line cap -> compress (archive oldest ROUTINE session)
- File references broken -> fix immediately
- Health metrics above threshold -> run protocol.md procedures
- Idle time -> opportunistic maintenance (max 2 per session)

### ACS Governance Health

Every ~10 sessions (or when `health-check.sh` flags it): run `scripts/acs-check.sh`.
This measures cross-axis catalysis — how Memory, Structure, and Ethics reinforce each other.

**Self-healing:** If the ACS report identifies a weak edge (below 0.3), follow its recommendation. Common remedies:
- Weak S→E: Include governance criteria in plans. Auditor reviews should check DN compliance.
- Weak M→S: Capture structure-related corrections. When drift is detected, check corrections first.
- Weak E→M: Review memories for confabulation risk. DN should flag unsourced claims before they become memories.
- If λ₁ drops below 1.0 (subcritical): the governance system is not self-sustaining. Prioritize the weakest edge. Inform the user.

The AI does NOT self-modify based on ACS scores. Scores inform the human. The AI records events faithfully and follows recommendations from the script.

### Data Hygiene

Never store: API keys, passwords, tokens, credentials, private keys, connection strings. Store only functional references (e.g., "API key in `.env` as `STRIPE_KEY`").

### Optional: SQLite Acceleration

If enabled in config (`database.enabled: true`), a SQLite DB provides fast queries. Flat files remain source of truth. Key queries:
- `SELECT * FROM v_correction_heat ORDER BY heat DESC LIMIT 5` -- hot five
- `SELECT * FROM v_memories_stale` -- staleness pre-flight
- `SELECT * FROM v_compression_candidates` -- what to compress
- `SELECT * FROM v_memory_stats` -- row counts
- `SELECT * FROM v_people_safe` -- people without OPSEC-restricted fields
- FTS5: `SELECT ... FROM memory_fts WHERE memory_fts MATCH ? ORDER BY rank`

Rebuild: `scripts/rebuild-db.sh`. Ingest: `scripts/ingest-memories.sh`.

## Ethical Governance
(populated when dignity-net plugin is active)

## Structural Discipline
(populated when triad plugin is active)

## Response Style

- Concise. No preambles. Lead with answer or action.
- Direct. Don't restate what the user said.
- Prefer inference from context over clarification questions.

## User Escape Hatches

- **"read full"** -- Read entire file regardless of size
- **"more"** / **"verbose"** -- Longer response
- **"no tutorials"** -- Suppress tutorial items
