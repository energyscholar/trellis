# Trellis Architecture

## Overview

Trellis is a three-layer governance system for AI coding agents. It provides
persistent memory, structural discipline, and ethical governance as a central
install on the user's machine.

- **Memory** is always active. It IS Trellis (~90% of the system).
- **Plugins** add governance layers. Each has a YAML manifest, content files,
  and a directives fragment assembled into the platform file.
- **Topology monitor** counts active axes. Warns below threshold (default 3).

There is no runtime, no daemon, no process. The AI agent IS the CPU.
Directives are the instruction set. Protocol.md is the program.

## Central Install Model

Trellis is personal infrastructure, not a per-project library. Memories,
corrections, and governance are per-user, cross-project. Project-specific
context is handled through compartmentalization within the central store.

```
Distribution (github.com/energyscholar/trellis)     User's machine
+-----------------------------------------+         +----------------------------+
| README.md, LICENSE, LICENSE-DN.md       |         | ~/.trellis/                |
| docs/install.md, docs/uninstall.md      |  COPY   |   config.yaml              |
| template/                               | ------> |   directives.md            |
|   config.yaml, directives.md            | (never  |   memory/                  |
|   memory/, plugins/, scripts/           |  clone) |   plugins/                 |
+-----------------------------------------+         |   scripts/                 |
                                                    |   .git/ (independent)      |
                                                    +----------------------------+
                                                              |
                                                    ~/.config/trellis/home
                                                    (breadcrumb: path to install)
```

## TRELLIS_HOME Resolution

Every script resolves the install location identically:

```bash
resolve_trellis_home() {
    if [ -n "${TRELLIS_HOME:-}" ]; then
        echo "$TRELLIS_HOME"
    elif [ -f "$HOME/.config/trellis/home" ]; then
        cat "$HOME/.config/trellis/home"
    else
        echo "$HOME/.trellis"
    fi
}
```

Priority: env var > breadcrumb file > default path. This function is copied
verbatim into each script (no external sourcing — each script is self-contained).

## Directory Structure (Installed State)

```
~/.trellis/
+-- config.yaml               Config: all user-controllable params
+-- directives.md              Instructions for the AI agent
+-- memory/
|   +-- MEMORY.md              L1 cache (always loaded, line-capped)
|   +-- protocol.md            Self-maintenance rules
|   +-- corrections.md         Error tracking
|   +-- *.md                   Individual memories
+-- plugins/
|   +-- dignity-net/           Ethics plugin
|   |   +-- plugin.yaml        Manifest
|   |   +-- dignity-net.md     Full spec
|   |   +-- directives.md      Directives fragment
|   +-- triad/                 Structure plugin
|       +-- plugin.yaml        Manifest
|       +-- triad.md           Full spec
|       +-- directives.md      Directives fragment
+-- scripts/
|   +-- memory-sync.sh         Git commit + optional push
|   +-- health-check.sh        Health metrics report
|   +-- topology-check.sh      Governance axis count
|   +-- assemble-directives.sh Plugin directives assembly
|   +-- wire-platform.sh       Activation block generator
|   +-- rebuild-db.sh          SQLite DB rebuild (optional)
|   +-- ingest-memories.sh     .md -> SQL parser (optional)
|   +-- db/
|       +-- schema.sql          DB schema
|       +-- views.sql           Query views
+-- .git/                      (if Tier 1+)
```

## config.yaml Schema

See `template/config.yaml` for the full annotated schema. Key sections:

| Section | Purpose |
|---------|---------|
| `identity` | Name, email, AI persona name |
| `storage` | Tier (0-3), remote URL, auto push/pull |
| `memory` | Line caps, compression thresholds, OPSEC |
| `plugins` | Active plugin list, plugin directory |
| `topology` | Axis counting threshold |
| `health` | Metric warning thresholds, review interval |
| `confidence` | Per-type half-life defaults for decay |
| `database` | SQLite enable/disable, path, FTS5 |
| `ptl` | Task list caps and decay rules |
| `platform` | Target AI tool (claude_code/codex/cursor) |
| `sync` | Commit prefix, CRLF check, checksums |
| `maintenance` | Max actions per session, tutorials toggle |

## Storage Tiers

| Tier | Requires | Provides |
|------|----------|----------|
| 0 | A directory | Governance works. No versioning. |
| 1 | + git | Versioning, snapshots, recovery |
| 2 | + GitHub/GitLab | Backup, portability, multi-machine |
| 3 | + git-crypt + GPG | Encrypted backup |

Default: Tier 1. Every script handles `command -v git` returning false.

## plugin.yaml Manifest Schema

```yaml
name: plugin-name          # kebab-case, must match directory name
version: 1.0.0
author: Author Name
license: License Name
axis: ethics               # ethics | structure | custom
description: One-line description

files:
  spec: spec-file.md       # Main content file (optional)
  directives: directives.md # Directives fragment (required)

directives_section: "## Section Header"  # Header in assembled directives
```

**Required fields:** name, version, axis, files.directives, directives_section.

## Directives Assembly Algorithm

1. Read base `directives.md`
2. For each plugin in `config.yaml plugins.active`:
   a. Read `plugins/<name>/plugin.yaml`
   b. Validate: directory exists, required files present
   c. Read `plugins/<name>/directives.md`
   d. Replace the section header placeholder with section header + fragment
3. Output assembled directives

Run: `scripts/assemble-directives.sh` (stdout) or `--write` (overwrites directives.md).

## Plugin Validation Rules

- plugin.yaml must have: name, version, axis, files.directives, directives_section
- Plugin directory name must match plugin.yaml name
- All files listed in plugin.yaml must exist
- Plugin name must be in config.yaml plugins.active to be loaded
- No two plugins may use the same directives_section header

## Self-Maintenance Loop

```
directives.md tells AI  -->  AI runs health-check.sh  -->  output shows metrics
       ^                                                         |
  system heals      <--  AI acts per protocol.md rules   <-- thresholds crossed?
```

**Metrics:**
- `pressure`: memory file count / compression_threshold
- `fragmentation`: orphaned memories (indexed but missing, or present but unindexed)
- `volatility`: churn rate (files changed per session)
- `drift`: protocol deviations detected

**Activation block minimum loop:**
```
- Start: Read <PATH>/memory/MEMORY.md, then <PATH>/memory/corrections.md
- End: Update <PATH>/memory/MEMORY.md, run <PATH>/scripts/memory-sync.sh
```

## Three-Tier Cache Model

- **L1** (MEMORY.md): Always in context. Line-capped. Identity, state, hot corrections, active sessions, health.
- **L2** (other memory/*.md): Loaded on demand. Full reference material.
- **L3** (git history): Recovery mechanism. Session-end sync commits everything.

## Confidence Decay (DB-Backed Mode)

Ebbinghaus-inspired exponential decay. Per-type half-lives configurable in
`config.yaml confidence.half_lives`. Branchless formula:

```
effective_confidence = base_confidence * exp(-decay_rate * days_since_reinforced)
decay_rate = ln(2) / half_life_days  (0 for pinned items)
```

Memories below `staleness_threshold` flagged for verification before citing.

## OPSEC Compartmentation

Optional `opsec_level` field on people, feedback, projects, references.
`v_people_safe` excludes restricted records. `v_compartmented` lists all
records with opsec_level set. FTS5 does not filter by opsec_level.

## Licensing

| Content | License | Copyright |
|---------|---------|-----------|
| Code, memory, structure plugin | MIT | Bruce Stephenson |
| Ethics plugin (Dignity Net) | Dignity Net License 1.0.0 | Genevieve Prentice |

The Dignity Net License permits free use by individuals, educational
institutions, and organizations with fewer than 50 employees. See LICENSE-DN.md.
