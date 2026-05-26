# Trellis

**Three-layer governance for AI coding agents.** Memory that persists.
Structure that separates planning from execution. Ethics that scale with risk.

Install Trellis from `https://github.com/energyscholar/trellis` — paste that
sentence into Claude Code, Codex, or Cursor. The AI does the rest.

---

## What Is Trellis?

AI coding assistants are stateless. Every conversation starts from zero.
Trellis gives them persistent memory, structural discipline, and ethical
governance — installed once on your machine, active across all projects.

**Memory** (built-in, always active): Corrections, session summaries,
decisions, contacts, task tracking. The AI maintains its own context.
Errors you correct once stay corrected.

**Structure** (Triad plugin): Role separation. The Auditor plans, the
Generator implements. No role collapse, no scope creep. Copy-paste is
the authorization gate between them.

**Ethics** (Dignity Net plugin): Proportional response from mirror to
refusal. Divergence detection without motive attribution. Storm protocol
for high-intensity exchanges.

The topology monitor counts active layers. Below threshold, it warns —
sub-threshold governance won't produce the stability you installed Trellis for.

---

## Install

### Fresh Install

Paste into your AI coding assistant:

> Install Trellis from https://github.com/energyscholar/trellis

The AI will:
1. Clone the repo to a temp directory
2. Copy `template/` to `~/.trellis/`
3. Initialize a local git repo (Tier 1)
4. Wire the activation block into your platform config
5. Ask your name and what you're working on

Total time: under 5 minutes. See [docs/install.md](docs/install.md) for
edge cases and custom paths.

### Restore from Backup

Already have a Trellis backup on GitHub (Tier 2+)?

```bash
git clone git@github.com:YOU/my-trellis.git ~/.trellis
```

Then tell your AI: "Wire Trellis." Your memories are already there.

---

## How It Works

### No Runtime

Trellis has no daemon, no process, no server. The AI agent IS the CPU.
`directives.md` is the instruction set. `protocol.md` is the program.

Every session:
- **Start:** AI reads `memory/MEMORY.md`, then `corrections.md`
- **End:** AI updates state, runs `scripts/memory-sync.sh`

That's the irreducible loop. Everything else builds on it.

### Three-Tier Cache

- **L1** (`MEMORY.md`): Always loaded. 200-line cap. Identity, state,
  hot corrections, active sessions, health metrics.
- **L2** (other `memory/*.md`): Loaded on demand. Full reference material.
- **L3** (git): Recovery backstop. Session-end sync commits everything.

### Corrections System

The most valuable component. Maintain a list of things the AI gets wrong
about your project. Each is a short imperative: what not to write, what
to write instead. The five most-violated rotate into L1.

Before corrections: same mistakes every session. After: near-zero repeats.

### Self-Maintenance

The AI maintains its own memory. Compression when approaching line cap.
Integrity checks at session end. Health metrics computed automatically.
The system heals itself.

### Optional: SQLite Acceleration

For mature installs, enable `database.enabled: true` in config.yaml.
Adds ranked full-text search (FTS5), confidence decay, evidence tracking,
and computed views. Flat files remain the source of truth.

---

## File Structure

```
~/.trellis/
+-- config.yaml                All user-controllable parameters
+-- directives.md              Instructions for the AI (assembled with plugins)
+-- memory/
|   +-- MEMORY.md              L1 cache (always loaded)
|   +-- protocol.md            Self-maintenance rules
|   +-- corrections.md         Error tracking
|   +-- *.md                   Individual memories
+-- plugins/
|   +-- dignity-net/           Ethics: proportional escalation L0-L5
|   +-- triad/                 Structure: Auditor/Generator role separation
+-- scripts/
|   +-- memory-sync.sh         Git commit + optional push
|   +-- health-check.sh        Health metrics report
|   +-- topology-check.sh      Governance axis count
|   +-- assemble-directives.sh Plugin directives assembly
|   +-- wire-platform.sh       Platform activation block
|   +-- rebuild-db.sh          SQLite rebuild (optional)
|   +-- ingest-memories.sh     Memory file ingestion (optional)
|   +-- db/                    Schema and views (optional)
```

See [docs/architecture.md](docs/architecture.md) for the full reference.

---

## Configuration

All parameters live in `config.yaml`. Key sections:

| Section | What it controls |
|---------|-----------------|
| `identity` | Your name, email, AI persona name |
| `storage` | Tier (0-3), remote URL, auto push/pull |
| `memory` | Line caps, compression, OPSEC |
| `plugins` | Which governance layers are active |
| `topology` | Minimum axis threshold |
| `health` | Metric warning thresholds |
| `confidence` | Per-type decay half-lives |
| `database` | SQLite enable, FTS5 |
| `platform` | Target: claude_code / codex / cursor |

---

## Talking to Your AI

Once installed, these work in any session:

**Corrections:** "You keep calling it GraphQL — it's REST. Add a correction."
The AI records it and checks it every session.

**Tasks:** "PTL add: fix the auth bug" / "PTL" / "PTL close PTL-003"

**Memory:** "What's in your memory?" / "Remember that Sarah prefers Slack."

**Health:** "Run health check" / "Run topology check"

---

## Storage Tiers

| Tier | Requires | Adds |
|------|----------|------|
| 0 | Directory | Governance works, no versioning |
| 1 | + git | Snapshots, recovery (default) |
| 2 | + GitHub private | Backup, multi-machine portability |
| 3 | + git-crypt + GPG | Encrypted backup |

Start at Tier 1. Upgrade when you need it. See [docs/storage-tiers.md](docs/storage-tiers.md).

---

## Plugins

Trellis ships with two governance plugins:

**Dignity Net** (ethics): Designed by Genevieve Prentice. Proportional
escalation from L0 Mirror through L5 Refusal. Storm protocol for
high-intensity exchanges.

**Triad** (structure): Role separation for human-AI collaboration.
Auditor plans, Generator implements. Explicit transitions only.

Create your own: [docs/plugin-development.md](docs/plugin-development.md).

---

## Security

**Memory files are committed to git.** At Tier 2+, they're on a remote
server. Use a private repository.

**Public repo guard:** `memory-sync.sh` checks if the GitHub remote is
public. If so, it REFUSES to push.

**Treat `~/.trellis/` like your shell config.** `directives.md` and
`corrections.md` control AI behavior — a malicious edit is a backdoor.

**Tier 3** adds encryption at rest via git-crypt for sensitive environments.

---

## Uninstall

Tell your AI: "Uninstall Trellis." It will offer Remove (delete everything)
or Reset (clear memories, keep governance). See [docs/uninstall.md](docs/uninstall.md).

Remote backups (Tier 2+) are not deleted — recoverable at any time.

---

## Licensing

| Content | License |
|---------|---------|
| Code, memory protocol, Triad plugin | MIT ([LICENSE](LICENSE)) |
| Dignity Net ethics plugin | [Dignity Net License 1.0.0](LICENSE-DN.md) |

The Dignity Net License permits free use by individuals, educational
institutions, and organizations with fewer than 50 employees. No derivatives
of the Dignity Net protocol without permission.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Additions should solve a real problem,
require no new dependencies, and fit the three-layer model.

---

## Contact

**energyscholar+consulting@gmail.com**

[![MIT License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
