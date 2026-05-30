---
name: skill-publish-and-show
description: Commit → push → wait for deployment → open in browser. Reduces friction by showing the user the live result instead of describing it.
metadata:
  type: skill
---

When the user needs to review a web artifact (HTML page, tutorial, visualization), the most effective communication tool is showing it live in their browser rather than describing it or asking them to navigate to it.

## The Pattern

1. `git add` + `git commit` the artifact
2. `git push` to the hosting remote (e.g., GitHub Pages via web-annex)
3. Poll until the deployment is live (`curl` the URL, check for 200)
4. `xdg-open` (or `open` on macOS) the URL in the user's default browser

## Why This Matters

- **Eliminates friction:** The user doesn't need to find the file, remember the URL, or manually open a browser. The result appears in front of them.
- **Shows the real artifact:** A rendered HTML page communicates what a code review cannot. CSS styling, SVG rendering, animation timing, responsive layout — these are only verifiable in a browser.
- **Closes the feedback loop:** The user sees the output immediately and can give feedback in the same session. No context switch, no "I'll look at it later."
- **Supports the Auditor verify step:** For web artifacts, browser verification IS the acceptance test. Opening the page is not a convenience — it's the verification method.

## When to Use

- After generating any HTML/web artifact intended for human review
- After any Generator phase that produces visual output
- When the user says "show me" or "let me see it"
- At the end of a multi-phase build before declaring completion

## Prerequisites

- The hosting remote must exist and be configured (e.g., GitHub Pages)
- The deployment pipeline must be known (GitHub Pages: push to main, wait ~30-60 sec)
- The URL pattern must be known for the user's specific hosting setup

Related: [[feedback-auditor-verify-cycle]]
