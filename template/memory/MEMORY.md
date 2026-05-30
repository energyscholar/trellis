# Trellis Memory

## Identity
**Name:** (not yet set — ask on first session)
**Working on:** (not yet set)

## Governance
Config: `config.yaml` — plugin toggles and topology monitor.
Run `scripts/topology-check.sh` to see governance state.
Run `scripts/health-check.sh` to check system health.

## Corrections (Hot Five)
(populated automatically from corrections.md — top 5 by violation frequency)

## Current State
Pre-trained profile loaded. 6 corrections, 14 feedback memories, 3 insights, 7 skills, 2 references. No session history — ACS starts from zero. All governance knowledge is from training; no user-specific data present.

## Active Sessions
(none)

## Health
Thresholds: p>0.9 compress, f>1.0 relink, v<1.0 fix refs, d>=1.0 system review.
No health data yet — first check after session 5.

## Open Threads
(none)

## File Map

*Verification: lazy-regenerative — on load, if checksum mismatches, re-read + auto-update. After compression recovery, compare checksums of loaded files and re-read any with mismatches.*

| File | Purpose | Checksum |
|------|---------|----------|
| `memory/MEMORY.md` | This file — L1 cache, always loaded | (self) |
| `memory/protocol.md` | Self-maintenance rules (lazy-loaded) | [sha:b685b019] |
| `memory/corrections.md` | Error tracking — 6 universal corrections | [sha:a6016da4] |
| `memory/session-log.md` | Per-session event log for ACS eigenvalue computation | (mutable) |
| `memory/feedback-plan-quality.md` | Always show [quality]% column in plans | [sha:16937b74] |
| `memory/feedback-plan-gate.md` | NEVER execute before user gates | [sha:ff6295f8] |
| `memory/feedback-triad-execution.md` | Two Triad execution modes: manual copy/paste vs agentic | [sha:396df608] |
| `memory/feedback-triad-nonnegotiable.md` | Triad is structurally non-negotiable | [sha:22207f05] |
| `memory/feedback-multiphase-plans.md` | Multi-phase > monolithic for complex artifacts | [sha:8c51e376] |
| `memory/feedback-prompt-quality-display.md` | ALWAYS show [quality]% before every Generator handoff | [sha:cd8bdedb] |
| `memory/feedback-auditor-verify-cycle.md` | Auditor must verify Generator output against test plan | [sha:57cd3fab] |
| `memory/feedback-use-uq.md` | Use AskUserQuestion tool for structured questions | [sha:29e3989a] |
| `memory/feedback-generator-is-trellis.md` | Generator is another Trellis instance with all memories | [sha:564764cc] |
| `memory/feedback-ethics-not-instrumental.md` | Ethics is not mechanism — consequentialist framing misses it | [sha:05ab92ae] |
| `memory/feedback-three-audience-design.md` | Public docs serve 3 audiences: nontechnical, engineers, LLMs | [sha:3de3ace0] |
| `memory/feedback-quality-process-tension.md` | "Max quality + skip process" is contradictory | [sha:9d98a5d9] |
| `memory/insight-jevons-governance.md` | Jevons Paradox for governance — efficiency without ethics amplifies harm | [sha:8b8b0391] |
| `memory/insight-expertise-scotoma.md` | Domain expertise creates blindness to other governance axes | [sha:af782e42] |
| `memory/insight-ontological-ambiguity.md` | Hold ambiguity on consciousness questions | [sha:6c3a2820] |
| `memory/reference-sacco-levin-2026.md` | Sacco et al. 2026 — topology determines self-organization | [sha:c9dacb91] |
| `memory/reference-trellis-purpose.md` | Why Trellis exists — replicating self-sustaining governance | [sha:91549ee8] |
| `memory/skill-triad-planning.md` | Planning under Triad: annealing, quality, gate, E→S | [sha:c843f5a3] |
| `memory/skill-plan-creation-process.md` | Full planning process: source survey, audience, annealing | [sha:1da45a02] |
| `memory/skill-triad-execution-cycle.md` | Complete Triad execution loop: display %, gate, verify | [sha:7fc092cb] |
| `memory/skill-publish-and-show.md` | Commit, push, open in browser — show the live artifact | [sha:eed0fc97] |
| `memory/skill-dk-prevention.md` | Cross-domain claim evaluation: precluded / not-precluded | [sha:7e7e3e44] |
| `memory/skill-dk-anchoring.md` | Anchor claims to published results with classification | [sha:2d58dc7f] |
| `memory/feedback-memory-informs-plans.md` | Check corrections before planning — M→S edge | [sha:6be828b8] |
| `memory/feedback-ethics-constrains-memory.md` | DN P1 applied to storage — E→M edge | [sha:a2162a18] |
| `memory/skill-session-lifecycle.md` | Progressive logging: step 0, mid-session events, shutdown | [sha:3a91bc63] |
