# Changelog

## [0.3.0] — 2026-05-27

### Added
- ACS governance measurement (`scripts/acs-check.sh`): cross-axis catalysis matrix on K3, depressed cubic eigenvalue solver in awk, self-healing recommendations per weak edge
- Session event log (`memory/session-log.md`): append-only markdown table, three axis columns, machine-parseable
- 4 starter corrections seeding cross-axis catalysis at install time
- ACS one-liner integrated into `health-check.sh` output
- ACS config section in `config.yaml` (window size, thresholds, check interval)
- Self-healing directives: weak-edge recommendations fed back through protocol

### Changed
- `directives.md`: session-end step 6 now includes event logging; ACS governance health section added
- `protocol.md`: session-end step 6 (log events), self-maintenance trigger for ACS check every ~10 sessions
- `corrections.md`: ships with 4 generic starter corrections instead of empty
- Uninstall reset preserves starter corrections and session-log format

## [0.2.0] — 2026-05-25

### Added
- Central install architecture (`~/.trellis/`)
- Memory layer ported from longmem v2.2.0 (protocol, directives, corrections, sessions, health)
- SQLite acceleration layer (schema, views, rebuild, ingest, FTS5, confidence decay, evidence)
- OPSEC compartmentation (optional `opsec_level` on people, feedback, projects, references)
- Dignity Net ethics plugin v1.0.0 (Genevieve Prentice, DN License)
- Triad structure plugin v1.0.0 (MIT)
- Plugin architecture with YAML manifests and directives assembly
- Platform adapters: Claude Code, Codex, Cursor
- `memory-sync.sh` — local commit + optional remote push with public repo guard
- `health-check.sh` — pressure, fragmentation, volatility, drift metrics
- `topology-check.sh` — governance axis counting vs threshold
- `assemble-directives.sh` — plugin directives assembly
- `wire-platform.sh` — activation block generator
- `rebuild-db.sh` — atomic SQLite rebuild with verification
- `ingest-memories.sh` — .md frontmatter to SQL parser
- Storage tiers (T0-T3) with security documentation
- LLM-executable install and uninstall flows
- Restore-from-backup install path
- Comprehensive config.yaml with 13 parameter sections
- Architecture reference document
- Test suite (7 tests: smoke, integrity, config, licenses, install, uninstall)
- TRELLIS_HOME resolution (env > breadcrumb > default) in all scripts

### Changed
- Restructured from per-project (`.trellis/`) to central install (`~/.trellis/`)
- Distribution uses `template/` directory (copied, not cloned)
- Install/uninstall docs moved to `docs/`

## [0.1.0] — 2026-05-21

Initial release. Per-project architecture.
