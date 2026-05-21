# Contributing to Trellis

Trellis is deliberately minimal. Every file and rule traces back to a specific, documented failure across 80+ sessions of real use.

## What's welcome

- **Bug fixes** — Especially cross-platform issues (macOS, WSL)
- **Documentation improvements** — Clearer instructions, better examples, typo fixes
- **Template improvements** — Better defaults, more helpful starter content
- **Troubleshooting additions** — If you hit a problem and solved it, document it

## What's out of scope for v1

- GUI or web interface
- Database backends or vector search
- Cloud sync or SaaS features
- Dependencies beyond bash + git
- Automation that removes user control

## How to contribute

1. **Small fixes**: Open a PR directly
2. **Larger changes**: Open an issue first to discuss rationale and design
3. **New memory files**: Must fit the three-tier cache model (see `.trellis/docs/architecture.md`)

## Running tests

Before submitting a PR, run the test suite:

```bash
bash tests/run-all.sh
```

All tests must pass. If you've intentionally changed template files, run `bash tests/test-hashes.sh --reset` to update the baseline.

## Design principles

- **Zero dependencies**: Markdown + YAML + bash + git. Nothing else.
- **AI-maintainable**: The AI manages its own memory. New features must be self-maintaining.
- **Failure-traced**: Every protocol rule should trace to a documented failure. "It seemed like a good idea" is not sufficient rationale.
- **Human-readable**: Files are edited by humans and AIs alike. No binary formats, no encoded state.

## Licensing

Trellis uses dual licensing:
- **MIT** — Code, memory templates, structural protocol (your contributions)
- **Dignity Net License 1.0.0** — Ethics layer content (authored by Genevieve Prentice, not accepting modifications)

By contributing, you agree that your contributions will be licensed under the MIT License.
