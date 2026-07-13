# Trellis Recovery — One Page

This file lives in your install (and therefore in your private memory repo),
so it survives the machine. If you are reading this after a crash, theft, or
hardware repair: your continuity anchor is your **private GitHub memory repo**,
not the machine.

## What "healthy" means

All six, verified by `scripts/health-check.sh`:

1. **Memory present** — `memory/MEMORY.md`, `memory/corrections.md`, `memory/protocol.md` exist.
2. **Directives assembled** — `directives.md` built from base + plugins (no placeholders).
3. **Plugins active** — dignity-net + triad load; Dignity Net matches its pinned canon version.
4. **Git clean** — no uncommitted memory changes.
5. **Remote reachable** — private repo configured, local HEAD pushed.
6. **Wall armed** — `git config core.hooksPath` = `scripts/git-hooks` (memory deletion wall active).

## Path A — New or repaired machine (full restore)

Prerequisites: git, GitHub CLI (`gh`) authenticated as the account that owns
your private memory repo.

1. Install the Trellis skeleton if `~/.trellis` does not exist yet
   (see `docs/install.md` in the distribution repo:
   clone it, copy `template/` to `~/.trellis/`).
2. Run the one command:

   ```bash
   bash ~/.trellis/scripts/restore.sh
   ```

   It runs, in order, idempotently (safe to re-run):
   `github-setup.sh --recover` (pull memory from your private repo) →
   `trellis-update.sh` (replace scripts with current distribution — the
   private repo carries whatever scripts were last committed, which may be
   stale) → `install-hooks.sh` (arm the deletion wall) → `wire-platform.sh`
   (print the activation block for your AI tool) → `health-check.sh`.
3. Add the printed activation block to your platform file
   (Claude Code: `~/.claude/CLAUDE.md`; Codex: `~/.codex/AGENTS.md`;
   Cursor: `~/.cursor/rules/trellis.mdc`). This wiring is machine-local and
   must be recreated on every new machine.
4. Confirm health-check reports the six marks above, especially `wall: armed`.

## Path B — Borrowed computer / browser only (no local install)

You cannot install anything, but you have GitHub access in a browser:

1. Open your private memory repo on GitHub.
2. Point a browser AI assistant with repo access at `BOOTSTRAP.md` in the
   repo root and follow it. That is enough to restore working continuity —
   read-mostly — until you are back on a real machine.
3. Do not attempt memory maintenance from a borrowed machine. Read, decide,
   note; write changes only after a full Path A restore.

## Before a machine leaves your hands (repair / shipping / disposal)

1. `scripts/memory-sync.sh` — commit everything; verify `git status` is clean.
2. `git push`, then verify nothing is unpushed: `git log origin/$(git rev-parse --abbrev-ref HEAD)..HEAD` must print nothing.
3. `git ls-remote origin HEAD` — confirm remote HEAD equals local HEAD.
4. Audit the repo for anything that must not live even in a private remote
   (credentials, tokens, third-party personal data, health details). Remove,
   commit, push.
5. Optional belt-and-suspenders: `tar czf` the install onto a drive you keep.
   This also covers the GitHub-lockout failure mode nothing else covers.
6. Record offline: repo URL, GitHub account, ai_name/profile values.

## Rules that keep recovery possible

- **Customize only `profiles/` and `scripts/fragments/`.** `directives-base.md`,
  `scripts/`, and `plugins/` are overwritten from the template on every
  `trellis-update.sh` run. Anything personal you put there will be lost.
- **Never assume a branch name.** Installs exist on both `main` and `master`;
  all Trellis scripts operate on the current branch.
- **Recovery never regenerates memory from a derived artifact.** Your flat
  `memory/*.md` files in the private repo are the food; the SQLite DB is a
  rebuildable cache. Restore only ever ADDS scripts — it must never touch
  `memory/` content except to copy your own files back in. The wall enforces
  this once armed, which is why the restore arms it before you resume work.
- **auto_pull stays false** for day-to-day use (a silent mid-session merge is
  a concurrent-writer hazard). `restore.sh` performs its pull explicitly and
  loudly. **auto_push stays true** — it is what makes the machine disposable.
