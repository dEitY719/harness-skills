---
name: ai-context
description: >-
  AI context doc dispatcher for CLAUDE.md / AGENTS.md / GEMINI.md — check,
  create, refactor. Use for "/harness:ai-context",
  "check my AGENTS.md", "create AI context file". Do NOT use for SKILL.md
  (authoring:skill-check) or *.sh (authoring:sh-check).
license: MIT
allowed-tools: Read, Glob, Grep, Write, Edit, Bash
metadata:
  model_recommendation:
    tier: sonnet
    reason: "dispatcher with bounded mutation (create/refactor write under confirmation); moderate analysis, not deep implementation"
    claude: prefer
    non_claude: advisory-only
---

# harness:ai-context — Unified AI Context Doc Skill

## Help

If `$1` is `-h`, `--help`, or `help`, read `references/help.md` and output
its content verbatim, then stop. No file reads beyond that.

## Step 1: Parse Args

Positional `[action] [path]`; flags `--file PATH`, `--type TYPE`, `-h`/`--help`.
`action` defaults to `check`, and is one of `check` / `create` / `refactor` /
`help`. Full table with defaults and precedence: `references/help.md`
"Arguments". Unknown action → print help and stop.

## Step 2: Resolve Target File

Run the deterministic half — auto-detection, alias collapse, `line_count` /
`c7`, and `size_class`:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/ai-context/scripts/detect-context.sh" \
  [--file PATH] [--type TYPE]
```

Read its `path` / `kind` / `other_candidates`. Output fields, the
multiple-file and no-file matrix, and the by-hand fallback when
`${CLAUDE_PLUGIN_ROOT}` cannot be resolved: `references/target-resolution.md`.

## Step 3: Dispatch by Action

### action=check (read-only)

Read `references/checks.md` and run **core + adapter** checks against the
target. Core checks always run; adapter checks vary by `type`. Quote line
ranges that drove each verdict. Never mutate the file.

### action=create (with confirmation)

Step 2 already reported `size_class`; map it to a template with
`references/templates/README.md`, which also records why the `claude-*`
templates exist alongside Claude Code's own `/init`. `gemini` has no native
template — offer the closest `agents-*` one with a manual-edit hint.

Read the matching template from `references/templates/`, fill placeholders
from discovery, present a plan, **wait for confirmation**, then write.

### action=refactor (with confirmation)

Read the existing file, list inline blocks / sections that should move to
nested files, present the split plan, **wait for confirmation**, then
extract sections and slim the root.

## Step 4: Report

Use `references/report-template.md` for every action. Verdict `[OK]` if no
FAIL, else `[FAIL]`. Always end with a `Next:` line per the same file.

## Constraints

- If any Step 1–3 step fails for a genuine reason (NOT a help print or an `authoring:skill-check` / `authoring:sh-check` routing stop — those are intentional early exits), report it via `references/report-template.md` with Verdict=`[FAIL]` and stop.
- `check` is audit-only — never mutate the file.
- Always confirm before overwriting in `create` / `refactor`.
- Auto-overwrite is never allowed when multiple context files exist.
- Honor `--file` and `--type` overrides over auto-detection.
- Cite `references/industry-baseline.md` for adapter-check rationale (Codex / Claude Code / Gemini CLI docs).
- Do NOT run on `SKILL.md` (route to `authoring:skill-check`) or `*.sh` (route to `authoring:sh-check`).
- No step here is Claude-Code-only, so the repo-root `references/*-tools.md` fallbacks do not apply.
