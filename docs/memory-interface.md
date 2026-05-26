# Memory System Interface

The memory layer is Trellis's built-in substrate. This document defines the
boundary between the memory system and the governance layer (plugins, topology
monitor, health checks) so that the memory implementation can evolve or be
replaced without breaking governance.

## Capabilities

What the memory system provides to the rest of Trellis.

### Storage

| Capability | Implementation | Interface |
|------------|---------------|-----------|
| Persistent key-value store | `memory/*.md` (frontmatter + body) | Read/write .md files with YAML frontmatter |
| Always-loaded index | `memory/MEMORY.md` | Hard cap from `config.yaml memory.memory_index_cap` |
| Error tracking | `memory/corrections.md` | Append-only correction records, hot-five rotation |
| Lifecycle rules | `memory/protocol.md` | Lazy-loaded, read when triggers fire |
| Individual memories | `memory/*.md` (feedback-*, project-*, etc.) | Typed via frontmatter `metadata.type` field |

### Operations

| Operation | Entry point | Notes |
|-----------|-------------|-------|
| Sync (commit + push) | `scripts/memory-sync.sh` | Flags: `--quick`, `--verify-only` |
| Health metrics | `scripts/health-check.sh` | Returns: pressure, fragmentation, volatility, drift |
| DB rebuild | `scripts/rebuild-db.sh` | Atomic swap, optional (DB is read cache) |
| Ingest .md → SQL | `scripts/ingest-memories.sh` | `--check-untagged` for hygiene scan |
| Full-text search | `SELECT ... FROM memory_fts WHERE memory_fts MATCH ?` | FTS5, porter tokenizer |
| Ranked search | `SELECT ... FROM v_fts_confidence WHERE memory_fts MATCH ?` | Text × confidence × recency |
| Staleness check | `SELECT * FROM v_memories_stale` | Below 50% confidence, needs verification |
| Compression candidates | `SELECT * FROM v_compression_candidates` | 4-stage: FULL → SUMMARY → ONE-LINER → ARCHIVE |
| Correction heat | `SELECT * FROM v_correction_heat ORDER BY heat DESC` | Severity-weighted violation frequency |
| Health shift detection | `SELECT * FROM v_health_shift WHERE has_significant_shift = 1` | Flags >0.2 delta between snapshots |

### Data Model

Memory files use YAML frontmatter:
```yaml
---
name: short-kebab-case-slug
description: one-line summary for relevance matching
metadata:
  type: user | feedback | project | reference | skill
---
```

Types: `user` (profile facts), `feedback` (behavioral rules with Why/How to apply),
`project` (active work state), `reference` (external pointers), `skill` (domain procedures).

## Contract

What the host (AI agent + activation block) must do for the memory system to function.

### Session Lifecycle

```
START                                    END
  │                                       │
  ├─ Read memory/MEMORY.md               ├─ Update memory/MEMORY.md
  ├─ Read memory/corrections.md          ├─ Write session summary
  ├─ Check .session-active (dirty flag)   ├─ Correction violation sweep
  └─ Set .session-active                  ├─ Run scripts/memory-sync.sh
                                          └─ Remove .session-active
```

### Periodic

- Every ~5 sessions: run `scripts/health-check.sh`
- If any metric above threshold: perform maintenance per `memory/protocol.md`
- On correction: update `memory/corrections.md`, track violation date

### Write Protocol

Before creating a memory file:
1. Will this matter in 30+ days?
2. Does existing memory cover this?
3. Derivable from code/git?
4. Contains context that can't be reconstructed?
5. Would a future instance behave differently without this?

All must pass. Then check for duplicates (novelty gate) before writing.

## Extension Points

Where the implementation can be swapped without changing the interface above.

| Extension Point | Current Implementation | Alternative |
|----------------|----------------------|-------------|
| **Storage backend** | Flat .md files in `memory/` | Key-value store, object storage, encrypted vault |
| **Search** | FTS5 (porter tokenizer, BM25) | Vector embeddings, hybrid search, external index |
| **Compression strategy** | 4-stage progressive (confidence-based thresholds) | LLM-driven summarization, semantic clustering |
| **Sync mechanism** | Git commit + push | Any versioning system, cloud sync, rsync |
| **Health metrics** | 4 dimensions (p/f/v/d) | Additional dimensions, weighted composites |
| **Confidence model** | Ebbinghaus exponential decay | Bayesian updating, usage-based, manual curation |
| **Index format** | Markdown with 200-line cap | Structured data, auto-generated from DB |

### Adding an Extension

Extensions replace implementations, not interfaces. To swap search:

1. New search must accept a text query and return `(source_table, source_id, title, relevance_score)` tuples
2. Protocol.md references to `memory_fts MATCH` become references to the new search function
3. directives.md query examples updated
4. `v_fts_confidence` view replaced or adapted

The governance layer (plugins) never calls the search directly — it goes through
the queries documented in directives.md. Change the queries, governance follows.

## Boundary Rules

1. **Plugins read memory, they don't manage it.** DN and Triad may reference
   corrections or session state, but they don't write to `memory/` or run
   maintenance. That's the memory system's job.

2. **Config is the only coupling.** Plugins and memory share `config.yaml` as
   their only coordination point. Plugins read `plugins.active`; memory reads
   `memory.*`, `confidence.*`, `database.*`.

3. **Scripts are self-contained.** Each script resolves TRELLIS_HOME independently.
   No script sources another. No shared library. This is deliberate — it means
   any script can be replaced without side effects.

4. **DB is a read cache.** Flat files are the source of truth. The DB can be
   deleted and rebuilt at any time. Any system that reads from the DB must
   tolerate its absence (fall back to file-based operations).
