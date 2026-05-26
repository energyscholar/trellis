# Plugin Development

Trellis plugins add governance axes on top of the built-in memory layer.
Each plugin is a directory under `plugins/` with a YAML manifest and a
directives fragment.

## Directory Structure

```
plugins/my-plugin/
+-- plugin.yaml        # Manifest (required)
+-- directives.md      # Directives fragment (required)
+-- my-spec.md         # Full specification (optional)
```

## plugin.yaml Manifest

```yaml
name: my-plugin            # kebab-case, must match directory name
version: 1.0.0
author: Your Name
license: MIT               # or any license
axis: custom               # ethics | structure | custom
description: One-line description of what this plugin governs

files:
  spec: my-spec.md         # Main content file (optional)
  directives: directives.md # Fragment assembled into directives (required)

directives_section: "## My Governance Section"  # Section header
```

**Required fields:** name, version, axis, files.directives, directives_section.

## Directives Fragment

The `directives.md` file in your plugin directory contains the instructions
that get assembled into the main `directives.md` at the install location.

Keep it short and imperative — under 150 words. Reference the full spec
file for details. Example:

```markdown
**Default behavior:** Apply rule X at all times.

**Trigger:** When condition Y is detected, escalate to action Z.

**Constraints:** Never do W without confirmation.

Full spec: `plugins/my-plugin/my-spec.md`
```

## Activation

Add your plugin to `config.yaml`:

```yaml
plugins:
  active:
    - dignity-net
    - triad
    - my-plugin    # add here
```

Then run `scripts/assemble-directives.sh --write` to rebuild directives.

## How Assembly Works

1. Base `directives.md` has section header placeholders (e.g., `## My Governance Section`)
2. Assembly script reads each active plugin's manifest
3. Replaces the section placeholder with the plugin's directives fragment
4. Inactive plugins keep the placeholder text

To add a placeholder for your plugin in the base directives, add:
```markdown
## My Governance Section
(populated when my-plugin is active)
```

## Validation Rules

- Plugin directory name MUST match the `name` field in plugin.yaml
- All files listed in `files:` MUST exist in the plugin directory
- `directives_section` MUST be unique across all active plugins
- Plugin MUST be listed in config.yaml `plugins.active` to be loaded

## Axis Types

| Axis | Purpose | Example |
|------|---------|---------|
| `ethics` | Behavioral/moral governance | Dignity Net |
| `structure` | Process/role separation | Triad |
| `custom` | Domain-specific governance | Your plugin |

The topology monitor counts 1 (memory, built-in) + count(active plugins).
Default threshold is 3 axes for full governance.

## Testing Your Plugin

1. Install plugin: copy directory to `~/.trellis/plugins/`
2. Add to config.yaml `plugins.active`
3. Add section placeholder to base `directives.md`
4. Run `scripts/assemble-directives.sh` — verify output contains your fragment
5. Run `scripts/topology-check.sh` — verify your plugin appears as ACTIVE
6. Validate manifest: `python3 -c "import yaml; yaml.safe_load(open('plugin.yaml'))"`
