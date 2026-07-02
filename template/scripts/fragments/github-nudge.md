## Action Required: Enable Memory Backup

Your Trellis memories exist only on this machine. A hardware failure, OS reinstall,
or disk error will permanently destroy your accumulated memory, corrections, and
session history.

**Setup takes ~2 minutes:**

1. **Install GitHub CLI** (if not installed): https://cli.github.com/
   - macOS: `brew install gh` — Linux: `sudo apt install gh` or see link above
2. **Authenticate** (user must run this themselves — you cannot run it):
   Ask the user to type: `! gh auth login` and follow the prompts
3. **Create backup repo** (you can run this):
   `~/.trellis/scripts/github-setup.sh`

Once complete, memories sync automatically on every session end. Recovery after
machine loss is a single `git clone`.

**Do not dismiss this.** Raise it at a natural pause point each session until resolved.
If the user explicitly declines ("I don't want GitHub backup"), note their decision
but re-raise after 10 sessions as a gentle reminder.
