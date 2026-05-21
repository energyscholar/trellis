# Trellis

A three-layer governance system for AI coding agents. Provides persistent
memory (what the system knows), structural role discipline (who decides),
and ethical constraints (how the system decides).

Most users start it for the memory. They keep it for the stability.

---

## What Is This?

AI coding assistants are stateless. Every conversation starts from zero. For a weekend script, that's fine. For a multi-week project with dozens of sessions, hundreds of decisions, and multiple collaborators — it's not workable.

**Trellis** solves this with three independently toggleable governance layers:

- **Memory** — Persistent context across sessions. Corrections, task tracking, decision logs, session summaries. Three-tier cache (L1 always loaded, L2 on demand, L3 via git history).
- **Structure** — Role separation between planning and execution. An Auditor defines success criteria and plans; a Generator implements exactly what's specified. Prevents scope creep, drift, and self-reinforcing errors.
- **Ethics** — Proportional behavioral governance. Detects divergence between stated goals and observable actions. Escalates from mirror (level 0) through friction, pattern flags, and consequence mapping to refusal (level 5). Modulates tone under emotional intensity without reducing substance.

Each layer works alone. Together, they produce qualitatively different stability — systems with 3+ constraint dimensions exhibit emergent governance properties that single-axis systems cannot.

**Evidence base (honest):** n=1 positive (80+ sessions, 0 catastrophic failures after governance established, 24 corrections with near-zero repeat violations). n=28 negative (documented failures in systems without governance). Suggestive, not conclusive.

---

## Quickstart

### Stage 1: Start Here (5 minutes)

**New project:**
```bash
git clone https://github.com/energyscholar/trellis.git my-project
cd my-project
```
Or use GitHub's "Use this template" button.

**Existing project:** Paste the install prompt from [`install.md`](install.md) into your AI coding agent. It clones Trellis, copies `.trellis/` into your project, and appends the activation block to your platform file (CLAUDE.md, AGENTS.md, or .cursorrules).

2. **Edit `.trellis/memory/MEMORY.md`** — fill in your project name, goal, key people
3. **Start your AI agent** from the project directory
4. **That's it.** The agent reads MEMORY.md and starts building context.

### Stage 2: After ~5 Sessions

- The AI will start making mistakes about your project. When it does, say: "Add a correction: [what's wrong] → [what's right]." It adds to `corrections.md` and checks it every session.
- If you're tracking tasks, say "PTL add: [task]." The AI manages `ptl.yaml`.
- Structure patterns emerge: the AI plans before building, flags scope creep.

### Stage 3: After ~10 Sessions

- MEMORY.md approaches 200 lines. The AI compresses automatically per protocol.
- Session-end sync (`.trellis/scripts/memory-sync.sh`) creates git snapshots for recovery.
- Full governance active: corrections inform escalation, role separation catches drift, topology monitor confirms all three axes.

---

## File Structure

```
trellis/
├── README.md
├── LICENSE                          # MIT (code, memory, structure)
├── LICENSE-DN.md                    # Dignity Net License 1.0.0 (ethics)
├── CONTRIBUTING.md
├── install.md                       # Install prompt for existing projects
├── uninstall.md                     # Uninstall prompt
├── CHANGELOG.md
├── .trellis/
│   ├── config.yaml                  # Layer toggles + topology monitor
│   ├── directives.md                # Unified directives (read at session start)
│   ├── memory/                      # Persistent context files
│   │   ├── MEMORY.md                # L1 cache (~200 lines, always loaded)
│   │   ├── protocol.md              # Session lifecycle rules
│   │   ├── corrections.md           # Error tracking (starts empty)
│   │   ├── ptl.yaml                 # Prioritized task list (starts empty)
│   │   ├── decisions.md             # Decision log (starts empty)
│   │   ├── people.md                # Key contacts
│   │   ├── breakthroughs.md         # Reasoning breakthroughs (starts empty)
│   │   └── session-details.md       # Session history (starts empty)
│   ├── ethics/                      # Behavioral governance (Dignity Net)
│   ├── structure/                   # Role separation (Triad protocol)
│   ├── scripts/                     # Sync, health, topology
│   ├── adapters/                    # Platform-specific activation generators
│   └── docs/                        # Architecture, case study, patterns
├── tests/                           # Test suite
└── .gitignore
```

---

## How It Works

**Three-tier cache model:**

- **L1** (`MEMORY.md`): Always in context. Capped at 200 lines. Contains identity, current state, the five most critical corrections, active session summaries, and health metrics.
- **L2** (other files in `.trellis/memory/`): Loaded on demand when depth is needed. Full reference material.
- **L3** (git history): Recovery mechanism. Session-end sync commits everything to git. When context compresses or sessions crash, git is the backstop.

**Corrections** are the most valuable memory component. You maintain a list of things the AI consistently gets wrong about your project. Each correction is a short imperative. The five most-violated rotate into L1 where they're visible every session. Before corrections: same mistakes every session. After: repeat violations near zero.

**Role separation** prevents the AI from planning and executing in the same breath. The Auditor writes plans and success criteria. The Generator executes. Neither expands the other's scope. Drift detection stops work when code is altered to pass tests or tests altered to pass code.

**Ethical governance** detects when stated goals and observable actions diverge, and responds proportionally. Level 0 (mirror) through Level 5 (refusal), scaled to pattern frequency and risk magnitude — never to emotional intensity. The Storm Protocol modulates tone under pressure without reducing substantive certainty.

**Topology monitor** checks that all three governance axes are active. Below threshold (default: 3 axes), it warns about specific governance gaps and their risks.

---

## Talking to Your AI

Once Trellis is set up, these interactions work in any session:

**Tasks:**
- `PTL` — Show your prioritized task list
- `PTL add: fix the auth bug` — Add a task
- `PTL close PTL-003` — Mark a task done

**Corrections:**
- "You keep calling it a REST API — it's GraphQL. Add a correction." → Added to `corrections.md` and enforced every session

**Structure:**
- "You are the Auditor" — Plan mode: define criteria, write plans, review output
- "You are the Generator" — Execute mode: implement the plan, nothing more
- "No role needed" — Governance inactive for quick questions or config tasks

**People:**
- "Remember that Sarah is my tech lead, prefers Slack over email." → Added to `people.md`

**Memory:**
- "What's in your memory?" → Summarizes what it knows
- "Sync memory" → Runs `memory-sync.sh`

---

## What Changes

| Before Trellis | After Trellis |
|----------------|---------------|
| ~30% of session re-explaining context | <5% |
| Same corrections every session | Near-zero repeat violations |
| Decisions lost between sessions | All decisions logged with rationale |
| No task continuity | Auto-tracked threads + structured tasks |
| Context window exhaustion | Tiered caching keeps context lean |
| Scope creep during implementation | Role separation enforces boundaries |
| Errors compound silently | Proportional escalation catches patterns |

Results from 80+ sessions (founding project, ongoing):
- **24 corrections established, repeat violations near zero**
- **Zero catastrophic context losses** (after governance established)
- **Context re-explanation: 30% → <5%**
- **Drift detection: multiple interventions** prevented compounding errors

---

## What Trellis is NOT

- **Not a plugin or extension** — It's files. No installation, no dependencies.
- **Not cloud-synced** — Memory lives on your filesystem + git. You own it.
- **Not automatic** — The AI maintains the memory, but you direct the project.
- **Not multi-user** — Each developer has their own memory. Share context via project docs.
- **Not a replacement for documentation** — Trellis is project context for the AI, not docs for humans.
- **Not a moral framework** — The ethics layer is behavioral governance, not philosophy. It detects divergence and responds proportionally.

---

## Licensing

Trellis uses dual licensing:

| Directory | License | Copyright |
|-----------|---------|-----------|
| `.trellis/memory/` | MIT | Bruce Stephenson |
| `.trellis/structure/` | MIT | Bruce Stephenson |
| `.trellis/scripts/` | MIT | Bruce Stephenson |
| `.trellis/adapters/` | MIT | Bruce Stephenson |
| `.trellis/docs/` | MIT | Bruce Stephenson |
| `tests/` | MIT | Bruce Stephenson |
| `.trellis/ethics/` | Dignity Net License 1.0.0 | Genevieve Prentice |

- **MIT** ([LICENSE](LICENSE)): Code, memory templates, structural protocol. Use, modify, redistribute freely.
- **Dignity Net License 1.0.0** ([LICENSE-DN.md](LICENSE-DN.md)): Ethics layer content. Free for individuals, education, and organizations under 50 employees. No derivatives. Organizations with 50+ employees require a commercial license (contact hello@dignityfield.org).

Ethics files carry per-file license headers. You can disable or remove the ethics layer entirely — the memory and structure layers work independently under MIT.

---

## Security & Privacy

**Memory files are committed to git.** If your repo is pushed to GitHub (public or private), all memory content — session history, people data, corrections, task priorities — will be visible to anyone with repo access.

**Treat `.trellis/` like code.** Review changes to `.trellis/` files in PRs with the same scrutiny as code changes. `directives.md`, `corrections.md`, and ethics files control AI behavior — a malicious edit is equivalent to a backdoor.

**Ethics files** contain behavioral governance rules. Verify them after installation (supply chain hygiene).

**Shared repos:** `.trellis/` contains personal project context. In team settings, either:
- Use per-developer directories (`.trellis-alice/`, `.trellis-bob/`)
- Add `.trellis/memory/people.md` and `.trellis/memory/session-details.md` to `.gitignore`
- Or agree as a team that memory content is shared

**Uninstall note:** `rm -rf .trellis/` removes files but history persists in git. For full removal: `git filter-repo --path .trellis/ --invert-paths` (requires force-push).

---

## Troubleshooting

**AI doesn't load MEMORY.md**
- Verify your platform file (CLAUDE.md, AGENTS.md, or .cursorrules) contains the TRELLIS START activation block
- Restart your AI agent from the project directory
- Check that `.trellis/memory/MEMORY.md` exists and is not empty

**memory-sync.sh fails**
- Run `git init` if this is a new project (script requires a git repo)
- Check file permissions: `chmod +x .trellis/scripts/*.sh`

**PTL commands not recognized**
- The AI needs to read `.trellis/directives.md` first — start from the project root
- Try: "Read `.trellis/directives.md` and then show me the PTL"

**MEMORY.md getting too long**
- Normal: the AI should compress automatically at 180 lines
- If not compressing: say "MEMORY.md is over 180 lines, please compress per protocol.md"

**Topology monitor shows axes missing**
- Check `.trellis/config.yaml` — each layer has an `enabled` flag
- Run `.trellis/scripts/topology-check.sh` for diagnostics

**Requirements:** An AI coding agent (Claude Code, OpenAI Codex, Cursor), git, bash. Tested on Ubuntu 22.04+ and macOS 13+. Windows: untested, should work under WSL2.

---

## Contact

For questions, bug reports, or consulting on structured governance systems for AI-assisted development:

**energyscholar+consulting@gmail.com**

---

[![MIT License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE) [![Dignity Net License](https://img.shields.io/badge/Ethics-Dignity_Net_1.0.0-green.svg)](LICENSE-DN.md)
