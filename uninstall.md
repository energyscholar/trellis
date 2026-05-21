# Trellis Uninstall Prompt

Paste this into your AI coding agent in your project directory:

---

Remove Trellis from this project. Steps:

1. Run `.trellis/scripts/memory-sync.sh` to create a final git snapshot
2. Show me what will be deleted (list files in .trellis/)
3. Ask for confirmation
4. After confirmation: rm -rf .trellis/
5. Remove the block between <!-- TRELLIS START --> and <!-- TRELLIS END --> from your platform file (CLAUDE.md, AGENTS.md, or .cursorrules)
6. If the platform file is now empty, delete it
7. Confirm removal is complete. Note: memory history is preserved in git — recoverable via `git log --all -- .trellis/`

---
