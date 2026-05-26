# Storage Tiers

Trellis supports four storage tiers. Each tier adds capabilities on top of
the previous one. You can upgrade at any time.

## Tier 0: Directory Only

**Requires:** A filesystem directory.
**Provides:** Full governance functionality. No versioning.

Memory files are plain markdown. All governance works. But there's no
version history, no recovery from accidental deletion, no snapshots.

**Who should use T0:** Users without git installed. Non-technical users
who just want the AI to remember things.

**Upgrade to T1:** `cd ~/.trellis && git init && git add -A && git commit -m "Initial"`

## Tier 1: Local Git (Default)

**Requires:** git installed.
**Provides:** Version history, snapshots, crash recovery.

The `memory-sync.sh` script commits memory state to a local git repo.
If a session crashes or context is lost, git history is the backstop.

**Who should use T1:** Most users. Good enough for single-machine use.

**Risks:** If the machine fails (disk crash, theft), memories are lost.
No off-machine backup.

**Upgrade to T2:**
```bash
cd ~/.trellis
# Create a PRIVATE repo first, then:
git remote add origin git@github.com:USER/my-trellis.git
git push -u origin main
```

## Tier 2: Remote Git

**Requires:** git + GitHub/GitLab/Gitea private repo.
**Provides:** Off-machine backup, multi-machine portability.

Clone on any machine, wire the entry point, fully operational:
```bash
git clone git@github.com:USER/my-trellis.git ~/.trellis
```

**Public repo guard:** `memory-sync.sh` checks if the remote is public
(GitHub only, requires `gh` CLI). If public, REFUSES to push and
tells the user how to fix it.

**Who should use T2:** Users who work on multiple machines, want backup,
or want recovery after hardware failure.

**Security:** Your memory files (session history, people, corrections,
project context) will be on GitHub's servers. Use a private repo.
Review what you're pushing — `git diff` before push.

**Upgrade to T3:**
```bash
cd ~/.trellis
git-crypt init
echo "memory/*.md filter=git-crypt diff=git-crypt" > .gitattributes
git-crypt add-gpg-user YOUR_GPG_KEY_ID
git add .gitattributes && git commit -m "Enable encryption"
git push
```

## Tier 3: Encrypted Remote

**Requires:** git + remote + git-crypt + GPG key.
**Provides:** Encrypted backup. Memory files encrypted at rest on remote.

Memory files are transparently encrypted on push and decrypted on pull.
On GitHub, the files appear as binary blobs. On the local machine,
they're readable markdown.

**Who should use T3:** Users with sensitive project context (security
research, legal work, trade secrets, personal information).

**Caveats:**
- git-crypt must be installed on every machine that accesses the repo
- GPG key management is the user's responsibility
- If you lose your GPG key, the encrypted files are unrecoverable
- `.gitattributes` patterns must cover all sensitive files

## Tier Comparison

| Feature | T0 | T1 | T2 | T3 |
|---------|----|----|----|----|
| Governance works | Y | Y | Y | Y |
| Version history | - | Y | Y | Y |
| Crash recovery | - | Y | Y | Y |
| Off-machine backup | - | - | Y | Y |
| Multi-machine | - | - | Y | Y |
| Encrypted at rest | - | - | - | Y |
| Requires git | - | Y | Y | Y |
| Requires account | - | - | Y | Y |
| Requires GPG | - | - | - | Y |
