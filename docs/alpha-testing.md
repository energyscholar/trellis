# Alpha Testing Guide

## What You're Testing

Trellis is a three-axis governance system for AI coding assistants. It gives your AI persistent memory, a self-correcting corrections system, and structural health metrics across three governance axes (strategy, ethics, memory). Alpha testing covers whether these pieces actually work in practice: does memory persist, do corrections stick, does the training primer teach the AI cross-axis reasoning, and does the health system catch real problems.

## Setup

**Prerequisites:** Claude Code CLI installed, git installed.

**Install:** Paste this into Claude Code:

```
Install Trellis from https://github.com/energyscholar/trellis
```

The AI clones the repo, copies the template to `~/.trellis/`, wires the activation block into your Claude Code config, and initializes a git repo. Under 5 minutes.

**Verify the install worked:**

- The AI should ask your name directly (not guess it from existing config)
- `~/.trellis/memory/corrections.md` should have 4 starter corrections
- `~/.trellis/memory/training-primer.md` should exist
- The AI should mention training primer Q1

If any of these are missing, see Troubleshooting below.

**Reference:** Open `docs/training-guide.html` in your browser. It has a session-by-session walkthrough with copy-paste prompts for each phase.

## Your First Session

Start a new Claude Code session after install. The AI reads `~/.trellis/memory/MEMORY.md` and `~/.trellis/memory/corrections.md` automatically via the activation block.

What should happen:

1. The AI finds `training-primer.md` and offers Q1 (Generator Drift)
2. You work through the question together -- it's a guided deduction, not a quiz
3. When you're done, say: **"Run the training session shutdown procedure"**
4. The AI marks Q1 complete in the primer, writes a session summary, and commits to the local git repo

One question per session. The training primer has 5 questions total, covering sessions 2 through 6.

## Updates

To check for available updates without applying them:

```
Run scripts/trellis-update.sh --check
```

To apply updates:

```
Run scripts/trellis-update.sh
```

Updates overwrite scripts and plugins (system files). They never touch your memories, corrections, or config identity fields. Your data stays yours.

## Sending Feedback

Your feedback helps improve Trellis. It is completely voluntary. There is no telemetry, no automatic data collection, no phone-home mechanism. The only way we get feedback is if you choose to send it.

### Quick Diagnostic

Paste this into your AI session:

```
Run scripts/trellis-diagnostic.sh and show me the output.
```

Review the output before sharing. It contains only structural metadata: version, session count, training primer progress, health metrics. No memory content, no corrections text, no personal data.

If you're comfortable sharing, copy-paste the output to [feedback channel TBD].

### What We Want to Know

- Did the AI ask your name on first session (not guess it from existing config)?
- Did it work one training primer question per session (not all at once)?
- Did the shutdown procedure complete all steps (mark progress, write summary, commit)?
- Did corrections persist across sessions?
- Any errors or confusing behavior?

### What We Don't Want

- Your memory content, corrections text, or personal details
- Screenshots of your conversations (unless illustrating a specific bug)
- Anything you're not comfortable sharing

## Troubleshooting

### "Trellis not found" or AI doesn't recognize Trellis

The install didn't complete. Check: `ls ~/.trellis/config.yaml` -- if the file is missing, reinstall.

### AI doesn't follow Trellis directives

Check that the activation block is in `~/.claude/CLAUDE.md`. Look for `<!-- TRELLIS START -->` and `<!-- TRELLIS END -->` markers. If missing, re-run the install or add the block manually (see `docs/install.md` step 4).

### AI tries all primer questions at once

Known early behavior. Say: **"Stop. One question per session. Read the training-primer.md pacing rules."**

### Memory doesn't persist between sessions

Check: `ls ~/.trellis/.git/` -- if there's no git repo, memory-sync has nowhere to commit. Fix:

```bash
cd ~/.trellis && git init && git add -A && git commit -m "Init"
```

### Reset to fresh state

```bash
cd ~/.trellis && scripts/trellis-profile.sh load blank
```

This loads the blank profile. Start a new session afterward so the AI re-reads the reset memory files.

## Known Limitations

- **Codex:** Designed and wired but not yet tested with alpha testers.
- **Cursor:** Minimal support (activation block only, no hooks or session-end sync).
- **ACS governance metrics:** Need 10+ sessions to produce meaningful measurements. Early sessions will show "need more data" -- that's expected.
- **Diagnostic script:** Reports structural metadata only. It cannot capture subjective issues like "the AI seemed confused" or "the corrections felt wrong." Your written feedback matters most for those.
