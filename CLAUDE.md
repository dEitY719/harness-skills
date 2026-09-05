# harness-skills — Contributor Guidelines

This file is the AI context document for this repo. Edit `CLAUDE.md`; never
replace the symlink with a second copy.

**When it loads, and who reads it.** Claude Code loads `CLAUDE.md` automatically
at session start as project memory — it is always in context, not fetched on
demand. `AGENTS.md` is a symlink to this same file, so Codex and the other
AGENTS.md-reading harnesses auto-discover it at the repo root and get identical
text, with no second copy to drift. Gemini CLI is the exception:
`gemini-extension.json` sets `"contextFileName": "GEMINI.md"`, and that file is a
separate, shorter skill index rather than a symlink. There are no nested
`AGENTS.md` files, so nothing overrides this one for a subtree.

## What this repo is

A single-plugin skill marketplace. The plugin is named `harness` and it bundles
five skills for managing the AI coding harness itself:

| Skill | Role |
|-------|------|
| `ai-context` | Check / create / refactor `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`. |
| `harness-legacy-check` | Read-only audit of the whole harness; writes a report. |
| `harness-refactor` | Applies that report's low-risk findings. |
| `dissect-builtin` | Documents a Claude Code built-in skill in Korean. |
| `plugin-guide` | Documents an installed plugin in Korean. |

It also owns two **shared assets** that the other fourteen `dEitY719/*-skills`
repos depend on. Those are the reason this repo exists as more than a fifth of a
split — see "Shared assets" below.

The skills were extracted from `dEitY719/dotfiles` (`claude/skills/devx-*`) as a
snapshot — see the first commit for the source SHA. The dotfiles copies remain
in place for now; they are removed in a later phase of that repo's migration
plan.

## Verifying a change locally

`validate.yml` calls the shared `skill-check` workflow, so CI is the real gate.
These four commands run its main assertions first, and all four are read-only.

```bash
# Every JSON manifest parses
git ls-files '*.json' | xargs -r -n1 jq empty

# The seven manifests agree on one version (prints exactly one line)
git ls-files '*.json' '*.yaml' \
  | xargs -r grep -hoE '"?version"?: *"?[0-9]+\.[0-9]+\.[0-9]+' \
  | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | sort -u

# Every SKILL.md stays under the 100-line progressive-disclosure limit
wc -l skills/*/SKILL.md | sort -rn

# No emoji in tracked text, over the same codepoint range CI rejects
git ls-files -z | xargs -0 grep -lP '[\x{1F000}-\x{10FFFF}\x{FE0F}]' \
  || echo "ok  no emojis"
```

This repo's own tracked check, which CI runs too:

```bash
bash tests/self-checks-step.sh
```

Then run the gate itself and watch it:

```bash
gh workflow run validate --ref "$(git branch --show-current)"
gh run watch
```

## Layout: root manifests, one flat `skills/`

This repo deliberately does **not** use the nested `plugins/<name>/skills/`
"mono" layout. Every harness manifest sits at the repo root and points at a
single flat `./skills/` directory:

```
.claude-plugin/{marketplace,plugin}.json   Claude Code
.codex-plugin/plugin.json                  Codex
.kimi-plugin/plugin.json                   Kimi CLI
.hermes-plugin/{plugin.yaml,__init__.py}   Hermes Agent
.opencode/plugins/harness.js               OpenCode
.agents/plugins/marketplace.json           Antigravity
gemini-extension.json + GEMINI.md          Gemini CLI
skills/<name>/SKILL.md                     the skills themselves
references/*-tools.md                      shared, owned here
```

Only Claude Code understands the nested mono layout. The other five harnesses
resolve manifests at the repo root and a skills tree at `./skills/`, so nesting
would silently cut this plugin down to Claude-Code-only. **Do not move the
manifests under a `plugins/` directory.**

## Shared assets — do not duplicate, do not relocate

**1. Per-harness tool mappings** (`references/*-tools.md`, dotfiles #1410 F-5).
Six files mapping skill actions onto each harness's real tool names. This repo
is the sole owner; the other fourteen repos link here. If you are about to paste
one into a sibling repo, stop and add a link instead — one tool rename must stay
one edit (NF-2). Details and the Kimi caveat: `references/README.md`.

**2. The reusable CI workflow** (`.github/workflows/skill-check.yml`, D-10).
A `workflow_call` workflow the other fourteen repos invoke with a `plugin-name`
input. Adding a check here applies it everywhere at once, which is the point.

Because a change here lands in fourteen other repos, treat this file as an API:

- **Never rename or remove an input.** Add new ones with a `default` so existing
  callers keep working.
- **Never add a check a sibling repo cannot pass** without confirming it passes
  there first. This repo's own `validate.yml` calls the workflow through a local
  `./` reference, so any change is proven here on its PR — but "green here" is
  not "green everywhere".
- Callers pin `@main`. There is no release train; a merge to `main` ships.

## Rules for changing skills

- **Skill directory name is the identity.** `skills/<name>/` must match the
  `name:` field in that skill's `SKILL.md` frontmatter, and that field is the
  **bare** name (`ai-context`), never namespaced (`harness:ai-context`). The
  harness supplies the `harness:` prefix at invocation time.
- **Invocation form in prose is namespaced.** Body text referring to a skill as
  a command writes `/harness:ai-context`.
- **Progressive disclosure.** `SKILL.md` stays under 100 lines (CI enforces it)
  and names which `references/` file to read and when. Detail lives in
  `references/`. Do not inline a reference file back into `SKILL.md`.
- **Description budget.** CI sums every skill description and fails past 5,440
  characters — Codex's context budget. Keep new descriptions tight.
- **Honour each skill's safety contract.** `harness-legacy-check` and
  `ai-context check` are read-only. `harness-refactor`, `ai-context create`, and
  `ai-context refactor` all confirm with the user before writing.
- **Harness gaps are documented, not worked around silently.** These skills
  assume Claude Code's `Workflow` and `Skill` tools. When you add a step that
  depends on a Claude-Code-only capability, add the fallback to all six
  `references/*-tools.md` files in the same commit.

## Version bumps

The version appears in seven manifests: `.claude-plugin/marketplace.json`,
`.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`,
`.kimi-plugin/plugin.json`, `.hermes-plugin/plugin.yaml`,
`gemini-extension.json`, and `package.json`. CI checks that they agree — bump
all of them together. Versioning is independent per repo (#1410 D-9); this repo
does not move in lockstep with its siblings.

## No emojis

Anywhere in this repo. Token efficiency.
