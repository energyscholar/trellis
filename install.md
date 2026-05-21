# Trellis Install Prompt

Paste this into your AI coding agent in your project directory:

---

Set up Trellis governance in this project. Steps:

1. Check: if `.trellis/` exists with MEMORY.md → already installed. Ask: reinstall/update/cancel.
2. Clone https://github.com/energyscholar/trellis.git to /tmp/trellis-install
3. Copy `.trellis/` directory into this project root
4. Ask: "Which platform? Claude Code / OpenAI Codex / Cursor"
5. Based on answer, append activation block to the platform file:
   - Claude Code → CLAUDE.md
   - Codex → AGENTS.md
   - Cursor → .cursorrules
   Activation block (same content for all, adjust comment syntax):

<!-- TRELLIS START — do not edit this block manually -->
## Trellis Governance

Full directives: `.trellis/directives.md` — read at session start for complete protocol.

**Minimum session loop:**
- **Start:** Read `.trellis/memory/MEMORY.md`, then `.trellis/memory/corrections.md`
- **End:** Update `.trellis/memory/MEMORY.md`, run `.trellis/scripts/memory-sync.sh`
<!-- TRELLIS END -->

6. chmod +x .trellis/scripts/*.sh
7. git init (if not already a git repo)
8. If .gitignore has `.*` but no `!.trellis/`, add `!.trellis/`
9. Open `.trellis/memory/MEMORY.md` — ask user to fill in project name, date, goal, people
10. Delete /tmp/trellis-install
11. Review `.trellis/directives.md` and `.trellis/scripts/memory-sync.sh` to verify they haven't been tampered with (standard supply chain hygiene)

---
