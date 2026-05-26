# Trellis Memory

## Identity
**Name:** (set during install)
**Working on:** (set during install)

## Governance
Config: `config.yaml` — plugin toggles and topology monitor.
Run `scripts/topology-check.sh` to see governance state.
Run `scripts/health-check.sh` to check system health.

## Corrections (Hot Five)
(populated automatically from corrections.md — top 5 by violation frequency)

## Current State
(updated each session with key context)

## Active Sessions
(session summaries appear here — oldest compress to session archive)

## Health
Thresholds: p>0.9 compress, f>1.0 relink, v<1.0 fix refs, d>=1.0 system review.
Run `scripts/health-check.sh` for current metrics.

## Open Threads
(auto-tracked recurring topics — max 5)

## File Map
| File | Purpose |
|------|---------|
| `memory/MEMORY.md` | This file — L1 cache, always loaded |
| `memory/protocol.md` | Self-maintenance rules (lazy-loaded) |
| `memory/corrections.md` | Error tracking |

(new memory files added here as they're created)
