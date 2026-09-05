# harness-skills

Five skills for managing the AI coding harness itself — audit and author its
context docs, audit and refactor its configuration, dissect a built-in skill,
document an installed plugin. Packaged as a single plugin named `harness`,
installable on six coding-agent harnesses.

This repo also owns two things the sibling `dEitY719/*-skills` repos depend on:
the [shared per-harness tool mappings](#shared-assets) and the
[reusable CI workflow](#ci).

## Skills

| Skill | Invoke | What it does |
|-------|--------|--------------|
| `ai-context` | `/harness:ai-context [check\|create\|refactor]` | Dispatcher for `CLAUDE.md` / `AGENTS.md` / `GEMINI.md`: audits one read-only, authors a new one from a size-matched template, or splits a bloated one into nested files. Not for `SKILL.md` or `*.sh`. |
| `harness-legacy-check` | `/harness:harness-legacy-check` | Read-only audit of the whole harness — context docs, skills, workflows, settings, hooks, MCP — saved to `.claude/reports/harness-legacy-check.md`. Changes nothing. |
| `harness-refactor` | `/harness:harness-refactor` | Reads that report, classifies findings by risk, generates `claude/workflows/harness-refactor.js` from the low-risk ones, and runs it. Anything risky lands in a "Human Approval Required" section instead. |
| `dissect-builtin` | `/harness:dissect-builtin <skill-name>` | Loads a Claude Code built-in skill and writes Korean docs (`README.md` + verbatim `PROMPT.md`) under `claude/built-in-skills/<name>/`. |
| `plugin-guide` | `/harness:plugin-guide <plugin>[@<marketplace>]` | Generates a Korean guide for an installed plugin from its cached `SKILL.md` files and updates the plugins index. Never installs, never commits. |

`harness-legacy-check` and `harness-refactor` are a pair: run the check first,
review its report, then run the refactor.

### Visual guides and worked examples (GitHub Pages)

- `ai-context` — [visual guide](https://deity719.github.io/harness-skills/skill-guides/ai-context.html) · [usage example](https://deity719.github.io/harness-skills/skill-output/ai-context-usage.html) (AI context doc to an audit verdict, a new file, or a split tree)
- `harness-legacy-check` — [visual guide](https://deity719.github.io/harness-skills/skill-guides/harness-legacy-check.html) · [usage example](https://deity719.github.io/harness-skills/skill-output/harness-legacy-check-usage.html) (whole harness to one read-only audit report)
- `harness-refactor` — [visual guide](https://deity719.github.io/harness-skills/skill-guides/harness-refactor.html) · [usage example](https://deity719.github.io/harness-skills/skill-output/harness-refactor-usage.html) (audit report to applied low-risk changes)
- `dissect-builtin` — [visual guide](https://deity719.github.io/harness-skills/skill-guides/dissect-builtin.html) · [usage example](https://deity719.github.io/harness-skills/skill-output/dissect-builtin-usage.html) (built-in skill to Korean docs plus its verbatim prompt)
- `plugin-guide` — [visual guide](https://deity719.github.io/harness-skills/skill-guides/plugin-guide.html) · [usage example](https://deity719.github.io/harness-skills/skill-output/plugin-guide-usage.html) (installed plugin to a Korean guide and an updated index)

Each page is generated from a Markdown source under
[`docs/skill-guides/`](docs/skill-guides) and [`docs/skill-output/`](docs/skill-output).

## Install

### Claude Code

```
/plugin marketplace add dEitY719/harness-skills
/plugin install harness@harness-skills
```

### Codex

```
codex plugin install dEitY719/harness-skills
```

### Kimi CLI

```
kimi plugin install dEitY719/harness-skills
```

### Hermes Agent

```
hermes plugins install dEitY719/harness-skills
```

### OpenCode

See [`.opencode/INSTALL.md`](.opencode/INSTALL.md).

### Gemini CLI / Antigravity

```
gemini extensions install https://github.com/dEitY719/harness-skills
```

Antigravity (`agy`) shares `~/.gemini`, so it inherits the install.

## Harness support

These skills are written in Claude Code's vocabulary. The other five harnesses
lack some of what they reach for — notably the `Workflow` tool and Claude Code's
built-in skill catalog. Every gap and its workaround is documented per harness
in [`references/`](references/); read the one file for the harness you are on.

| Skill | Claude Code | Codex | Kimi | Gemini / Antigravity | Hermes | OpenCode |
|-------|:-----------:|:-----:|:----:|:--------------------:|:------:|:--------:|
| `ai-context` | full | full | full | full | full | full |
| `harness-legacy-check` | full | manual | manual | manual | manual | manual |
| `harness-refactor` | full | manual | manual | manual | manual | manual |
| `dissect-builtin` | full | n/a | n/a | n/a | n/a | n/a |
| `plugin-guide` | full | needs Claude Code installed | needs Claude Code installed | needs Claude Code installed | needs Claude Code installed | needs Claude Code installed |

*manual* — the skill's steps work, but you run them yourself instead of through
a workflow runtime; the output contract (report path, generated JS plan) is
unchanged. *n/a* — the skill reads Claude Code's built-in skill catalog, which
no other harness can reach.

## Shared assets

### Per-harness tool mappings (dotfiles #1410 F-5)

[`references/{codex,kimi,gemini,antigravity,hermes,opencode}-tools.md`](references/)
map the actions skills speak in ("dispatch a subagent", "run a workflow", "ask
the user") onto each harness's real tool names, and list what each harness
cannot do.

**This repo is their sole owner.** The other fourteen `*-skills` repos link
here rather than carrying copies — one tool rename should be one edit, not
fifteen (#1410 NF-2). See [`references/README.md`](references/README.md).

### Plugin-root resolution convention

[`references/plugin-root.md`](references/plugin-root.md) answers "where are my
bundled files" for all six harnesses. `${CLAUDE_PLUGIN_ROOT}` is the only
mechanism these plugins use to locate their own files and only Claude Code sets
it, so the file fixes one resolution order, one canonical snippet per carrier,
and the rule that an empty variable is never spliced into a path. Owned here,
linked from the siblings.

## Layout

Manifests live at the repo root and all point at one flat `skills/` directory:

```
.
├── skills/{ai-context,harness-legacy-check,harness-refactor,dissect-builtin,plugin-guide}/
│   ├── SKILL.md
│   └── references/
├── references/*-tools.md                        shared, owned here
├── references/plugin-root.md                    shared, owned here
├── .claude-plugin/{marketplace,plugin}.json     Claude Code
├── .codex-plugin/plugin.json                    Codex
├── .kimi-plugin/plugin.json                     Kimi CLI
├── .hermes-plugin/{plugin.yaml,__init__.py}     Hermes Agent
├── .opencode/plugins/harness.js + INSTALL.md    OpenCode
├── .agents/plugins/marketplace.json             Antigravity
├── gemini-extension.json + GEMINI.md            Gemini CLI
├── package.json
├── CLAUDE.md · AGENTS.md -> CLAUDE.md
└── LICENSE
```

Only Claude Code understands a nested `plugins/<name>/skills/` layout. The other
five harnesses resolve manifests at the repo root and a skills tree at
`./skills/`, so this repo keeps everything flat. See [`CLAUDE.md`](CLAUDE.md) for
the full rationale and contribution rules.

The `.kimi-plugin/` manifest is pre-provisioned: Kimi CLI is not installed on the
maintainer's machines yet, and shipping the manifest now costs nothing and saves
a migration later.

## CI

[`.github/workflows/skill-check.yml`](.github/workflows/skill-check.yml) is a
`workflow_call` reusable workflow owned by this repo (#1410 D-10). It validates
manifests, skill frontmatter, progressive-disclosure line limits, the Codex
description budget, version agreement, and shell scripts, and it runs the
repo's own checks.

Every `dEitY719/*-skills` repo calls it instead of copying it:

```yaml
jobs:
  validate:
    uses: dEitY719/harness-skills/.github/workflows/skill-check.yml@main
    with:
      plugin-name: <plugin>
```

This repo calls it too, through a local `./` reference
([`validate.yml`](.github/workflows/validate.yml)), so a change to the shared
workflow is proven on its own PR before a sibling repo picks it up.

### Where a repo's tests live

One convention for every `dEitY719/*-skills` repo, so the workflow discovers
checks instead of being taught each repo's shape:

- **`tests/` is the home.** A check outside it is not discovered and does not
  run.
- **`tests/run.sh`, if tracked, is the sole entry point.** It owns ordering and
  is expected to run everything else under `tests/`.
- **Otherwise every `tests/*.sh` is one check**, run in `git ls-files` order.
  Direct children only — `tests/lib/helper.sh` is a helper, not a check.
- **Offline.** No network, no `gh` auth, no package install. A check that needs
  any of those does not belong in CI.
- **A repo with no `tests/` prints `ok    no tests tracked` and passes.** There
  is no opt-in input; committing `tests/` is the opt-in.

This repo tracks one such check itself
([`tests/self-checks-step.sh`](tests/self-checks-step.sh)): it extracts the
step from the workflow and runs it against fixture repos, so the discovery
rules above are executed rather than described.

An existing check in another shape is adapted by a two-line `tests/` script
rather than by widening discovery:

```bash
#!/usr/bin/env bash
exec bash skills/symlink-manager/lib/symlink_migrate.sh --self-test
```

## Provenance

These skills were extracted from
[`dEitY719/dotfiles`](https://github.com/dEitY719/dotfiles)
(`claude/skills/devx-{ai-context,harness-legacy-check,harness-refactor,dissect-builtin,plugin-guide}`)
as a content snapshot — no history rewriting. The source commit SHA is recorded
in this repo's first commit message. The `devx-` prefix is dropped here because
the plugin namespace (`harness:`) now supplies it.

This is Phase 1 of the dotfiles #1410 migration; `packaging-skills` was Phase 0.

## License

MIT. See [LICENSE](LICENSE).
