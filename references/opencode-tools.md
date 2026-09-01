# OpenCode Tool Mapping

Skills speak in actions. On OpenCode these resolve to the tools below. Read this
file when a skill names a tool you do not recognise.

## Tools

| Action skills request | OpenCode equivalent |
|---|---|
| Read a file | `read` |
| Create a file / edit a file | `apply_patch` |
| Run a shell command | `bash` |
| Search file contents | `grep` |
| Find files by name | `glob` |
| Task tracking (`TodoWrite`) | `todowrite` |
| Ask the user / confirm | Ask in the conversation and wait for the reply |
| Dispatch a subagent | `task` with `subagent_type: "general"` (or `"explore"`, read-only) |
| Invoke a skill | OpenCode's native `skill` tool |

## Invoking a skill

Installation is via `opencode.json`, not a plugin command — see
[`../.opencode/INSTALL.md`](../.opencode/INSTALL.md). Once
`.opencode/plugins/harness.js` has registered `./skills`, use the native tool:

```
use skill tool to list skills
use skill tool to load harness-legacy-check
```

The plugin injects no per-session bootstrap context on purpose: these skills are
task-triggered, so native `skill` discovery is all that is needed and a
bootstrap preamble would be pure per-session cost.

## Progressive disclosure

The `skill` tool loads `SKILL.md`. When a step says "read
`references/checks.md`", `read` that path relative to the skill's directory **at
that step** — not up front.

## Subagent dispatch

`task` with an explicit `subagent_type`:

- `"explore"` for read-only sweeps — fanning out the
  `harness:harness-legacy-check` audit across context docs, `skills/`,
  workflows, settings, hooks, and MCP config.
- `"general"` for children that write — `harness:dissect-builtin`'s two parallel
  documentation writers (README.md and PROMPT.md).

If a skill's prose says `Subagent (general-purpose):`, that is Claude Code's
type name; read it as "an agent with no special role" and use `"general"`.

## Capability gaps

**No workflow runtime.** `harness:harness-legacy-check` calls
`Workflow({ name: 'harness-legacy-check' })` and `harness:harness-refactor`
calls `Workflow({ scriptPath: 'claude/workflows/harness-refactor.js' })`. Those
are Claude Code tools; OpenCode has no `Workflow` tool. Note the trap here:
OpenCode's plugin system *is* JavaScript, so it looks like
`harness-refactor.js` could just be run. It cannot — that file is written
against Claude Code's workflow API, not OpenCode's plugin API. Do not `bash
node claude/workflows/harness-refactor.js`.

Instead:

- Run the audit's sweeps with `read` / `grep` / `bash`, or fan the independent
  ones out with `task` (`subagent_type: "explore"`).
- Write the report to `.claude/reports/harness-legacy-check.md` regardless —
  that path is the contract `harness:harness-refactor` reads from.
- For `harness-refactor`, still generate `claude/workflows/harness-refactor.js`:
  it is the reviewable plan of record and a Claude Code session can execute it
  later. Then apply its low-risk edits yourself with `apply_patch`.

**No Claude Code built-in catalog.** `harness:dissect-builtin` Step 1 loads a
Claude Code built-in's raw prompt with `Skill(skill: "<name>")`. OpenCode's
`skill` tool resolves the skills registered in its own config, not Claude Code's
built-ins. Run that skill from Claude Code, or supply the prompt by hand and
start at Step 2.

**Plugin cache belongs to Claude Code.** `harness:plugin-guide` scans
`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/cache/<marketplace>/<plugin>` and
resolves marketplaces against `claude/plugin/plugins.json`. Both are Claude Code
/ dotfiles artifacts. Readable from OpenCode with `bash` when they exist on this
machine; otherwise the skill has no input and should stop rather than retarget
itself at OpenCode's own plugin list, which has a different shape.

## Read-only and confirmation contracts

- `harness:harness-legacy-check` and `harness:ai-context check` are strictly
  read-only. Never reach for `apply_patch` or a mutating `bash` command while
  following them.
- `harness:ai-context create` / `refactor`, `harness:harness-refactor`, and any
  `--force` overwrite print a plan and **wait**. With no structured question
  tool, state the plan, ask, and end your turn. An auto-approve permission mode
  is not the user's answer.
