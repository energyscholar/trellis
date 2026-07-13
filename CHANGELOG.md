# Changelog

## [0.5.0] — 2026-07-13

### Added
- Memory deletion wall (`scripts/git-hooks/pre-commit` + `scripts/install-hooks.sh`): commits that delete a top-level `memory/*.md`, or move one out of the read path (e.g. into `memory/archive/`), are blocked. In-place renames allowed. Deliberate override via `ALLOW_MEMORY_DELETE=1` is permitted and logged to `health/deletion-attempts.log`.
- Recovery UX: `RECOVERY.md` (one-page restore guide, lives in the install so it travels in the private memory repo), `BOOTSTRAP.md` (browser-only bootstrap prompt), `scripts/restore.sh` (one-command restore: recover → update → arm wall → wire → health-check).
- `health-check.sh`: re-arms the wall idempotently on every run and reports "wall: armed"; identity check (config `ai_name` vs active profile); Dignity Net canon pin check (`plugins.dn_version` + `plugins.dn_checksum` in config); one imperative DO-NEXT line per non-OK check.
- `rebuild-db.sh` snapshot freshness gate: never rebuild from a `data-*.sql` snapshot older than the memory files — regenerate from markdown first (a frozen snapshot silently strands every memory written after it).
- `tests/test-wall.sh` (wall behavior) and `tests/test-portability.sh` (macOS/BSD lint: no `grep -P`, `md5sum`, `stat -c`, `date -d`, bare `sed -i`, `realpath` in `template/scripts/`).

### Changed
- `trellis-update.sh`: stage-and-swap replacement of `scripts/` and `plugins/` (no window with scripts deleted; a crash mid-update can no longer strip an install or its wall); stamps the new version into the user's `config.yaml` (the version gate otherwise never advances); runs `install-hooks.sh` as the final step.
- `ingest-memories.sh`: CRLF-tolerant frontmatter parsing (a `\r` on the fence made memories silently unrecallable); absolute `--output` paths honored (was silently writing nothing); portable mtime/date handling; `flock` fallback for macOS; SQL-escaping fixes.
- `memory-sync.sh`: portable SHA-256 hashing that fails loud when no hash tool exists; explicit per-path staging (no `git add -A`, and no all-or-nothing pathspec list); pulls the current branch instead of assuming `main`.
- `github-setup.sh`, `trellis-profile.sh`: portable in-place sed; no hardcoded branch names; profile load passes the wall via logged override (the swap is deliberate and auto-saved first).
- Version bumped to 0.5.0.

## [0.4.0] — 2026-05-27

### Added
- Update mechanism (`scripts/trellis-update.sh`): pull latest from GitHub, overwrite system files, preserve user data. `--check` flag for dry run.
- Diagnostic report (`scripts/trellis-diagnostic.sh`): structured metadata report for alpha tester feedback. No personal data, user-initiated copy-paste only.
- Alpha testing guide (`docs/alpha-testing.md`): setup, session workflow, feedback prompts, troubleshooting
- Directives-base.md pattern: `assemble-directives.sh` reads from unassembled base template, writes to assembled directives.md. Idempotent reassembly.
- `config.yaml`: `update.repo_url` field for configurable update source
- Codex install notes in `docs/install.md` (Tier 2, auto_push/pull, AGENTS.md)
- Update/diagnostic awareness in `directives.md`

### Changed
- `assemble-directives.sh`: reads from `directives-base.md` if present (fixes duplicate assembly bug)
- `docs/install.md`: directives-base.md step, Codex notes, update section
- `docs/uninstall.md`: SessionEnd hook removal step, Codex-specific notes
- Version bumped to 0.4.0

## [0.3.1] — 2026-05-27

### Added
- Memory profile system (`scripts/trellis-profile.sh`): save, load, list, delete, current, interactive menu
- Profile pin/unpin: protect test baselines from session-end auto-save
- Profile export/import: portable .tar.gz archives for moving profiles between machines
- SessionEnd hook (`scripts/trellis-hook-session-end.sh`): auto-sync memory + auto-save profile
- Training primer (`memory/training-primer.md`): 5 guided deduction questions targeting weak K3 edges
- Session start directive: training primer loaded for sessions < 10

### Changed
- `directives.md`: Memory Profiles section expanded with pin/unpin/export/import commands
- SessionEnd hook respects pinned profiles (routes auto-save to `_autosave`)
- `memory/MEMORY.md` template: file map includes training-primer.md
- Install verification checklist includes training-primer.md

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
