# Uninstall Trellis

Two modes: **Remove** (delete everything) or **Reset** (clear memories, keep governance).

## Remove

Complete removal of Trellis from the system.

### Steps

1. **Find installation:** Check `$TRELLIS_HOME`, `~/.config/trellis/home`, `~/.trellis/`
2. **Confirm intent:** Remove / Reset / Cancel
3. **Safety check:** Verify directory looks like Trellis (has config.yaml, memory/, plugins/). If not, REFUSE to delete.
4. **Final snapshot:** If git available, commit all changes. If remote configured, push.
5. **Remove activation blocks:** Find and remove `<!-- TRELLIS START -->` ... `<!-- TRELLIS END -->` markers from:
   - `~/.claude/CLAUDE.md` (Claude Code)
   - Any paths listed in config.yaml `projects` list
   - `~/.cursor/rules/trellis.mdc` (Cursor — delete entire file)
6. **Delete installation:** `rm -rf ~/.trellis/` (or custom path)
7. **Remove breadcrumb:** `rm -f ~/.config/trellis/home`
8. **Confirm:** Note that remote backup (if Tier 2+) is NOT deleted and remains recoverable.

## Reset

Clear memories but keep protocols, plugins, and scripts. For starting fresh.

### Steps

1. **Find installation**
2. **Delete memory files:** All `memory/*.md` except `protocol.md`, `session-log.md`, `corrections.md`
3. **Reset MEMORY.md:** Restore to template state (identity blank, no sessions)
4. **Reset corrections.md:** Restore to starter corrections (the 4 generic cross-axis seeds, not empty — they're infrastructure)
5. **Reset session-log.md:** Restore to empty table header (clear session history but keep the format)
6. **Commit:** `git commit -am "Reset memories"`
7. Done. Protocols, plugins, scripts, config, starter corrections preserved. ACS data cleared.

## Edge Cases

| Case | Handling |
|------|----------|
| Can't find installation | Ask user for path |
| Uncommitted changes | Force final commit before delete |
| Remote push fails | Warn, proceed (local snapshot exists) |
| Activation block corrupted | Regex fallback, then manual instructions |
| Config file empty after marker removal | Delete the file |
| Directory doesn't look like Trellis | REFUSE to delete |
