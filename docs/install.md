# Install Trellis

## Quick Install

Paste this into your AI coding assistant:

> Install Trellis from https://github.com/energyscholar/trellis

The AI will clone the repo, copy the template to `~/.trellis/`, and wire the
activation block. Total time: under 5 minutes.

## Fresh Install Steps

### 1. Check for existing installation

Check in order: `$TRELLIS_HOME` env var, `~/.config/trellis/home` breadcrumb,
`~/.trellis/` default. If found, offer: update / reinstall / cancel.

### 2. Choose install location

Default: `~/.trellis/`. User may specify a custom path.
Always use `$HOME` in scripts, never `~`.

### 3. Create the install

```bash
# Clone distribution to temp location
git clone https://github.com/energyscholar/trellis.git /tmp/trellis-install

# Copy template to install location
cp -r /tmp/trellis-install/template/ "$HOME/.trellis/"

# Clean up temp
rm -rf /tmp/trellis-install

# Initialize git (Tier 1)
cd "$HOME/.trellis"
git init
git add -A
git commit -m "Trellis initial install"
```

If git is not available: skip git init (Tier 0 mode). Warn the user about
lost versioning and recovery capabilities.

If git user.name/email not configured: set repo-local defaults:
```bash
git config user.name "Trellis"
git config user.email "trellis@local"
```

### 4. Wire the entry point

Run `scripts/wire-platform.sh auto` to detect the platform and generate the
activation block. Supported platforms:

| Platform | Target file | Format |
|----------|-------------|--------|
| Claude Code | `~/.claude/CLAUDE.md` | Markdown with `<!-- TRELLIS START/END -->` markers |
| Codex | User-specified `AGENTS.md` | Same markdown format |
| Cursor | `~/.cursor/rules/trellis.mdc` | MDC with YAML frontmatter |

If the target file doesn't exist: create it with just the activation block.
If a TRELLIS block already exists: replace it in-place (idempotent).
If no trailing newline before block: prepend one.

### 5. Assemble directives

Run `scripts/assemble-directives.sh --write` to assemble base directives
with active plugin fragments.

### 6. Personalize

Ask the user for:
- Their name
- What they're working on
- Key collaborators (optional)

Fill in `memory/MEMORY.md` Identity section.

### 7. Write breadcrumb

```bash
mkdir -p "$HOME/.config/trellis"
echo "$HOME/.trellis" > "$HOME/.config/trellis/home"
```

### 8. Verify

- [ ] `~/.trellis/config.yaml` exists
- [ ] `~/.trellis/memory/MEMORY.md` exists and has identity filled in
- [ ] `~/.trellis/directives.md` exists and contains plugin sections
- [ ] All scripts in `~/.trellis/scripts/` are executable
- [ ] Activation block present in platform config file
- [ ] `scripts/health-check.sh` reports all OK
- [ ] `scripts/topology-check.sh` reports 3/3

## Restore from Backup

For existing Trellis users setting up a new machine (Tier 2+):

```bash
git clone git@github.com:USER/my-trellis.git ~/.trellis
```

Then wire the entry point (step 4) and verify (step 8). All memories
are already in the clone.

## Edge Cases

| Case | Handling |
|------|----------|
| Existing install found | Offer: update / reinstall / cancel |
| Custom path with spaces | Quote ALL paths |
| `~` in scripts | Always use `$HOME` |
| Path inside another git repo | Warn, suggest alternative |
| Git not installed | Tier 0. Warn about lost capabilities. |
| Git user.name/email not set | Set repo-local defaults |
| Config file doesn't exist | Create with activation block only |
| TRELLIS block already present | Replace in-place (idempotent) |
| Offline | "Download the repo manually and tell me the path" |
| Partial previous install | Back up, fresh install |
| macOS case-insensitive FS | Use exact case for all files |
| Multiple platform files detected | Ask which to wire, or wire all |
