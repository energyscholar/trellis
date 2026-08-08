# Updating Trellis

**Audience: the Trellis instance performing the update, and the person supervising it.**

Trellis is normally driven by an AI assistant, so this document is written to be
read by one. If you are that assistant: read the whole page before running
anything, and do not skip §2 — it describes an unrecoverable deletion.

Per-release notes live in [CHANGELOG.md](../CHANGELOG.md) and on the
[releases page](https://github.com/energyscholar/trellis/releases). This page
describes the *mechanism*, which does not change between releases.

---

## 0. Before you start — check what version you are on

The update path branches on this, so establish it first:

```bash
grep '^version:' ~/.trellis/config.yaml
```

**No output — there is no `version:` key.** The updater will exit **1 with no
message at all** (`set -euo pipefail` plus a `grep` that matches nothing), and
nothing will happen. It fails closed, so nothing is damaged, but you get no
explanation. Add the key and re-run:

```bash
printf 'version: 0.0.0\n' | cat - ~/.trellis/config.yaml > /tmp/c && mv /tmp/c ~/.trellis/config.yaml
```

**Version is 0.5.0 or later.** Normal path. Continue to §1.

**Version is older than 0.5.0.** The updater replaces *itself*, so the copy that
runs is your **old** one, and version stamping plus the final `install-hooks.sh`
re-arm did not exist before 0.5.0
([issue #13](https://github.com/energyscholar/trellis/issues/13)). Your first run
will report success, leave `version:` stale, and — importantly — leave the
**memory deletion wall unarmed**. Run the updater a **second** time, then confirm:

```bash
grep '^version:' ~/.trellis/config.yaml                 # must show the new version
git -C ~/.trellis config core.hooksPath                 # must show scripts/git-hooks
```

---

## 1. Check, then update

```bash
bash ~/.trellis/scripts/trellis-update.sh --check    # report only
bash ~/.trellis/scripts/trellis-update.sh            # apply
```

The updater clones the repo's **default branch** and compares
`template/config.yaml`'s `version:` against your install's. If they match it
prints `Already up to date` and exits **before** the check path.

⚠ **"Already up to date" is not proof you are current.** It only means the two
version strings are equal. If a release is merged but the version line is not
bumped, every install is told it is up to date while missing the work. This has
happened — see the v0.5.1 release notes. If you suspect it, compare your
`~/.trellis` against the repo directly rather than trusting the gate.

---

## 2. ⚠ Custom plugins and scripts are destroyed

The updater replaces `scripts/` and `plugins/` **wholesale**, then deletes the
staged copies:

```bash
mv "$TRELLIS/plugins"     "$TRELLIS/plugins.old"
mv "$TRELLIS/plugins.new" "$TRELLIS/plugins"
rm -rf "$TRELLIS/scripts.old" "$TRELLIS/plugins.old"   # the backup goes too
```

Anything in those two directories that the distribution does not ship is **gone,
with no on-disk backup**. This is [issue #27](https://github.com/energyscholar/trellis/issues/27)
and it is not yet fixed. If you have written your own plugin, this will delete it.

**Always, before updating:**

```bash
cp -r ~/.trellis/plugins ~/trellis-plugins-backup-$(date +%Y%m%d)
cp -r ~/.trellis/scripts ~/trellis-scripts-backup-$(date +%Y%m%d)
```

Restore your own directories by name afterwards. Do not restore wholesale — that
would put the old distribution files back and undo the update.

### What is and is not touched

| Path | What happens |
|---|---|
| `scripts/`, `plugins/` | **replaced wholesale — local additions destroyed** |
| `directives-base.md`, `RECOVERY.md`, `BOOTSTRAP.md`, `.gitignore` | overwritten |
| `directives.md` | reassembled from base + plugins — local edits lost |
| `config.yaml` | **only the `version:` line is changed** |
| `memory/`, `profiles/` | untouched |

Your memories, session log, corrections and profiles are safe. The memory
deletion wall is re-armed at the end by `install-hooks.sh`.

---

## 3. Config keys are NOT backfilled

The updater stamps the `version:` line and nothing else. New keys added by a
release do not appear in your `config.yaml`, and changed values are not updated.
This is [issue #12](https://github.com/energyscholar/trellis/issues/12).

The consequence you are most likely to hit: a release that designates a new
**Dignity Net canon** ships the new plugin file while your config still pins the
old version and checksum, so `health-check.sh` reports the canon **DRIFTED on
every run** until you re-pin by hand.

⚠ **That warning's own advice is wrong in this situation.** It reads:

> DO-NEXT: Run scripts/trellis-update.sh to restore canonical Dignity Net (or
> re-pin dn_version/dn_checksum in config.yaml if a new canon was deliberately
> designated).

Re-running the updater will report `Already up to date` and change nothing — the
versions already match. **The second clause is the correct one.**

**After every update**, diff your config against the distribution and add what is
missing:

```bash
diff <(git clone -q --depth 1 https://github.com/energyscholar/trellis /tmp/t-cfg && \
       cat /tmp/t-cfg/template/config.yaml) ~/.trellis/config.yaml; rm -rf /tmp/t-cfg
```

Take the release's new keys and any changed pins; keep your own values for
everything else.

---

## 4. Procedure

```bash
# 1. confirm you have a rollback
git -C ~/.trellis rev-parse --git-dir >/dev/null 2>&1 && echo "git rollback available"

# 2. back up what will be destroyed
cp -r ~/.trellis/plugins ~/trellis-plugins-backup-$(date +%Y%m%d)
cp -r ~/.trellis/scripts ~/trellis-scripts-backup-$(date +%Y%m%d)

# 3. check and apply
bash ~/.trellis/scripts/trellis-update.sh --check
bash ~/.trellis/scripts/trellis-update.sh

# 4. restore your own plugins/scripts by name

# 5. reconcile config keys (§3)

# 6. verify
bash ~/.trellis/scripts/health-check.sh
```

Read the release notes for the version you landed on — they carry anything
specific to it.

### Rollback

If your install is a git repo, the updater commits a **"Pre-update snapshot"**
before touching anything:

```bash
git -C ~/.trellis log --oneline | grep 'Pre-update snapshot'
git -C ~/.trellis reset --hard <that commit>
```

If it is **not** a git repo you have no rollback, and §2's backup is your only
route back. Make the install a git repo before updating:
`git -C ~/.trellis init && git -C ~/.trellis add -A && git -C ~/.trellis commit -m "pre-update"`.

---

## 5. Requirements worth checking first

The SQLite acceleration layer needs a `sqlite3` built with **math functions** and
**FTS5**. Without them `schema.sql` fails to load, there is no database, and the
failure surfaces as unrelated-looking errors elsewhere
([issue #25](https://github.com/energyscholar/trellis/issues/25)):

```bash
sqlite3 :memory: "select ln(2);"                        # expect 0.693...
sqlite3 :memory: "create virtual table t using fts5(x);" # expect no error
```

---

## 6. Per-release upgrade notes

- [v0.5.1](UPGRADING-0.5.1.md) — first release an existing install could receive
  after 0.5.0; moves the Dignity Net canon to v1.4 and makes
  `database.enabled: false` actually work.
