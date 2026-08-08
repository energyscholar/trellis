# Changelog

## [Unreleased]

## [0.5.1] — 2026-08-07

Interim release. It ships work that had been merged since 0.5.0 but was
undeliverable: the version line never moved, and `trellis-update.sh` returns
early when the installed and template versions match, so every install reported
"Already up to date (v0.5.0)" while missing all of the below — including a
Dignity Net version change.

**Upgrading from 0.5.0 requires three manual edits to `config.yaml`.** The
updater replaces `scripts/` and `plugins/` but stamps only the `version:` line in
your config; it does not backfill new or changed keys (#12). Because
`plugins/dignity-net/` becomes v1.4 while your config still pins v1.2,
`health-check.sh` will report the canon **DRIFTED** on every run until you set:

```yaml
plugins:
  dn_version: "1.4"
  dn_checksum: "f6a43a8844232410cdd27069ead0ef49afed41e4a28c5e6c9345d6c35a6cb5fc"
health:
  volatility_review: 0.50        # new key
```

### Added
- **Dignity Net v1.4 is now canon** (#14), replacing v1.2. Adds asymmetry as an explicit ontological and governance concern ("unchecked asymmetry magnifies distortion"), a risk-magnitude check — *can affected people correct, refuse, and recover?* — the North Star "Hold a coherent container", and "identity is rhythmic". The canon pin in `config.yaml` moves to `1.4` with a new checksum; see the upgrade note above.
- **Section-aware config resolution** (#21). `template/scripts/lib/config.sh` is now the single implementation of `get_config`, which had been copy-pasted five times. Bare keys keep their existing behaviour; `SECTION.KEY` resolves within the named block, and surrounding quotes are stripped.

### Fixed
- **`database.enabled: false` was ignored — the documented flat-file mode had never worked** (#21). Every copy of `get_config` grepped `^\s*KEY:` and took `head -1`, i.e. the first match at *any* nesting depth, so `memory.enabled` (line 24) shadowed `database.enabled` (line 104). `health-check.sh` rebuilt the database and reported `sqlite: ON` against a config that disables it. Four of the five old copies also could never return their own default, because the pipeline's exit status was the wrong one to test.
- **Memory health mechanics** (#9): unindexed memories now warn instead of passing silently, the volatility review trigger is defined (`health.volatility_review`), and the last `bc` dependency is gone from the health check — it had been printing `0.00 [OK]` for every metric on any install without `bc`.
- ACS and every other reader of `session-log.md` now accept the pre-v0.5 bare-numeric session id (`| 17 |`) alongside the current `| S22 |` form. The strict `^\| S[0-9]` matcher in `acs-check.sh`, `proprioceptive-check.sh`, `trellis-profile.sh`, and `stress-test-compare.sh` silently excluded an installation's entire pre-update history, reporting "insufficient data (have 0)" against a log with 18 valid rows. (#8)
- `tests/test-integrity.sh` no longer passes when it cannot run its own checks. The plugin and manifest checks piped `python3` output into `for` with stderr discarded, so a missing PyYAML produced an empty list, an unexecuted loop body, and a green result meaning "skipped". Extraction failure is now a test failure, and a repo with manifests that checked none of them fails too. (#6)
- `tests/run-all.sh` and `CONTRIBUTING.md` now offer install routes that work on externally-managed Python (PEP 668 — Debian 12+, Ubuntu 23.04+, Homebrew), where the previously documented `pip install -r requirements-test.txt` is refused outright. (#7)
- `acs-check.sh` no longer aborts on macOS. Line 403 interpolated an unbraced `$first_session` immediately followed by an en-dash; bash 3.2 folds the multi-byte character into the variable name, so `set -u` killed the script with `first_session…: unbound variable` after printing two lines of header. Every macOS install with enough sessions to reach the report was affected — it went unseen only because the sole known macOS install short-circuited earlier on the #8 bug, which means fixing #8 is what would have walked it into this crash.
- `CONTRIBUTING.md` no longer instructs contributors to run `tests/test-hashes.sh --reset`; no such script exists in the repo.

### Added (testing)
- `tests/test-acs-session-formats.sh`: regression coverage for numeric-only, `S`-prefixed-only, and mixed session logs, asserting session count, first/last identifier, and provenance parsing across `acs-check.sh` and `proprioceptive-check.sh`.
- CI (`.github/workflows/tests.yml`): the suite on ubuntu and macOS, a job asserting the suite fails *loudly* without PyYAML rather than skipping (#4's last criterion), and a standalone portability lint. The macOS `acs-check.sh` abort above was caught by this workflow's first run.
- `tests/test-portability.sh` now flags an unbraced `$var` followed by a byte outside printable ASCII — the bash 3.2 unbound-variable trap, which is invisible on inspection and invisible on Linux.

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
