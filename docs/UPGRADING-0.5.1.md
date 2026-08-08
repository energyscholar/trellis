# Upgrading an established install to v0.5.1

**Audience: the Trellis instance doing the upgrade, and the person supervising it.**

This document exists because v0.5.1 is the first release in a while that an
existing install can actually receive, and the updater was written for a simpler
install than yours. Read it before running anything. It describes what will
change *on disk*, what will be destroyed, and what you must repair afterwards.

Everything below was verified by simulating this exact upgrade on a scratch
install, not read off the source.

---

## 1. Why your install thinks it is current

Six PRs merged after 0.5.0 and none of them reached you. `template/config.yaml`
was never bumped, and the updater returns before its own check path when the two
versions match:

```bash
if [ "$OLD_VERSION" = "$NEW_VERSION" ]; then
    echo "Already up to date (v${OLD_VERSION})." >&2
    exit 0
fi
```

So `--check` has been answering **"Already up to date (v0.5.0)"** on an install
missing all six — including a Dignity Net canon change. If you have been running
DN **v1.2** while believing you were current, this is why. That is the defect
0.5.1 exists to clear.

---

## 2. ⚠ Back up first — custom plugins and scripts will be destroyed

The updater replaces `scripts/` and `plugins/` **wholesale**, then deletes the
staged copies. Anything in those two directories that the template does not ship
is gone, with **no on-disk backup**. This is issue #27.

Verified on a scratch install carrying one custom plugin and one custom script:

```
delete mode 100644 plugins/gen-custom-plugin/manifest.yaml
delete mode 100644 plugins/gen-custom-plugin/plugin.md
delete mode 100644 scripts/gen-local-helper.sh
```

**Before you upgrade:**

```bash
cp -r ~/.trellis/plugins ~/trellis-plugins-backup-$(date +%Y%m%d)
cp -r ~/.trellis/scripts ~/trellis-scripts-backup-$(date +%Y%m%d)
```

Then restore your own plugin directories afterwards. If your install is a git
repo, the updater also makes a **"Pre-update snapshot"** commit, which is a
second route back — confirm you have one before starting:

```bash
git -C ~/.trellis rev-parse --git-dir >/dev/null 2>&1 && echo "git rollback available"
```

### What is NOT touched

`memory/` and `profiles/` are left completely alone — verified. Your memories,
session log, corrections and profiles survive the upgrade untouched. The
deletion wall is re-armed at the end by `install-hooks.sh`.

| Path | What happens |
|---|---|
| `scripts/`, `plugins/` | **replaced wholesale, customisations destroyed** |
| `directives-base.md`, `RECOVERY.md`, `BOOTSTRAP.md`, `.gitignore` | overwritten |
| `directives.md` | reassembled from base + plugins — local edits lost |
| `config.yaml` | **only the `version:` line is changed** |
| `memory/`, `profiles/` | untouched |

---

## 3. Repair three config keys immediately afterwards

The updater does not backfill new or changed config keys (issue #12). Because
`plugins/dignity-net/` becomes **v1.4** while your config still pins **v1.2**,
`health-check.sh` will report the canon **DRIFTED on every run** until you edit
`~/.trellis/config.yaml` by hand:

```yaml
plugins:
  dn_version: "1.4"
  dn_checksum: "f6a43a8844232410cdd27069ead0ef49afed41e4a28c5e6c9345d6c35a6cb5fc"

health:
  volatility_review: 0.50        # new key — review when one commit touches this
                                 # fraction of memory files
```

⚠ **The DRIFTED warning's own advice is wrong here.** It says:

> DO-NEXT: Run scripts/trellis-update.sh to restore canonical Dignity Net (or
> re-pin dn_version/dn_checksum in config.yaml if a new canon was deliberately
> designated).

Re-running the updater will report "Already up to date" and change nothing —
the versions now match. **The second clause is the correct one.** Re-pin by hand.

---

## 4. One behaviour change that may surprise you

**`database.enabled: false` now actually works** (#21). `get_config` had been
copy-pasted five times, each grepping `^\s*KEY:` and taking the first match at
*any* nesting depth — so `memory.enabled` shadowed `database.enabled`, and the
documented flat-file mode had never worked. If your config sets
`database.enabled: false`, sqlite genuinely turns off after this upgrade, where
before it was ignored and the database was built anyway.

If you *want* the database, confirm the setting says so rather than relying on
the old bug.

Two smaller ones: unindexed memories now **warn** instead of passing silently
(#9), so an established memory set may surface warnings it never showed before —
those are real findings, not upgrade damage. And `health-check.sh` no longer
needs `bc`; installs without it had been printing `0.00 [OK]` for every metric,
so your first post-upgrade health report may be the first true one you have seen.

---

## 5. Procedure

```bash
# 1. back up what the updater will destroy
cp -r ~/.trellis/plugins ~/trellis-plugins-backup-$(date +%Y%m%d)
cp -r ~/.trellis/scripts ~/trellis-scripts-backup-$(date +%Y%m%d)

# 2. confirm the update is visible
bash ~/.trellis/scripts/trellis-update.sh --check      # expect: v0.5.0 → v0.5.1

# 3. upgrade
bash ~/.trellis/scripts/trellis-update.sh

# 4. restore your own plugins/scripts from the backup, by name

# 5. repair the three config keys in §3

# 6. verify
bash ~/.trellis/scripts/health-check.sh                # expect: dignity-net matches pinned canon v1.4
```

**Rollback**, if the install is a git repo:

```bash
git -C ~/.trellis reset --hard <the "Pre-update snapshot" commit>
```

---

## 6. What you are getting

- **Dignity Net v1.4 is canon** (#14) — asymmetry as an explicit ontological and
  governance concern ("unchecked asymmetry magnifies distortion"), the
  risk-magnitude check *can affected people correct, refuse, and recover?*, the
  North Star "Hold a coherent container", and "identity is rhythmic".
- **Memory health mechanics** (#9, closing #3) — unindexed memories warn instead
  of passing silently, the volatility review trigger is defined, and the last
  `bc` dependency is gone.
- **PyYAML declared as a test dependency** (#5), with PEP 668 install routes (#7).
- **Section-aware config resolution** (#21) — see §4.
- ACS accepts pre-v0.5 bare-numeric session ids (#8); `acs-check.sh` no longer
  aborts on macOS bash 3.2; `test-integrity.sh` no longer passes when it cannot
  run its own checks (#6); CI runs on ubuntu and macOS (#11).

## 7. Known-open, so you are not surprised later

- **#27** — the plugin/script destruction described in §2. Not fixed in 0.5.1.
- **#12** — config keys are not backfilled. §3 is the manual workaround.
- **#25** — `schema.sql` needs a sqlite3 built with math functions and FTS5. If
  yours lacks them the database silently fails to build and surfaces as
  unrelated-looking test failures. Check with:
  `sqlite3 :memory: "select ln(2);"` and
  `sqlite3 :memory: "create virtual table t using fts5(x);"`
