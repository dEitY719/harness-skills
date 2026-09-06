# Kimi CLI Tool Mapping

Skills speak in actions. On Kimi CLI (Kimi Code) these resolve to the tools
below. Read this file when a skill names a tool you do not recognise.

> Kimi CLI is **pre-provisioned** in this repo family (dotfiles #1410 D-5): the
> manifests ship before the CLI is installed on the maintainer's machines, so
> this mapping is written from Kimi Code's published tool surface and has not
> been exercised end to end. Trust your actual tool list over this table when
> they disagree, and file an issue so this file can be corrected.

## Tools

| Action skills request | Kimi Code equivalent |
|---|---|
| Read a file | `Read` |
| Create a file | `Write` |
| Edit a file | `Edit` |
| Run a shell command | `Bash` |
| Search file contents | `Grep` |
| Find files by name | `Glob` |
| Task tracking (`TodoWrite`) | `TodoList` |
| Ask the user / confirm | `AskUserQuestion` |
| Dispatch a subagent | `Agent` with `subagent_type: "coder"` or `"explore"` |
| Invoke a skill | Skills load from `./skills/` via the plugin manifest; read the `SKILL.md` directly if no loader tool is exposed. |

Kimi Code's names collide with Claude Code's for the file and shell tools, so
most of a skill's prose transfers unchanged. The differences that matter are
`TodoWrite` -> `TodoList` and the subagent types.

Kimi CLI exports no plugin-root variable. When a skill hands you a shell
block that reads `${CLAUDE_PLUGIN_ROOT}`, `export` it yourself to the directory
you read the `SKILL.md` from, before running the block — otherwise the block
stops rather than guessing. Full rule:
[`plugin-root.md`](plugin-root.md).

## Subagent dispatch

`Agent` with an explicit `subagent_type`:

- `"coder"` for anything that writes files — e.g. `harness:dissect-builtin`'s
  README.md documentation agent.
- `"explore"` for read-only sweeps — e.g. fanning out the
  `harness:harness-legacy-check` audit across `skills/`, hooks, and settings.

**Never pass `general-purpose`** — that is Claude Code's type name and Kimi
rejects it. If a skill's prose says `Subagent (general-purpose):`, read it as
"an agent with no special role" and pick `coder` or `explore` by whether the
child writes.

## Progressive disclosure

Skills say "read `references/help.md`" and mean it literally: `Read` that path,
relative to the skill's directory, at the step that names it. Do not preload a
skill's whole `references/` tree.

## Where the shared mapping lives

This file is the source of truth. `.kimi-plugin/plugin.json` carries a condensed
copy in its `skillInstructions` field because Kimi injects that string at load
time and has no way to fetch a reference file on demand. When the two disagree,
this file wins — and update both.

## Capability gaps

**No workflow runtime.** `harness:harness-legacy-check` calls
`Workflow({ name: 'harness:harness-legacy-check' })`; `harness:harness-refactor` calls
`Workflow({ scriptPath: '.claude/workflows/harness-refactor.js' })`. Kimi Code
exposes no `Workflow` tool and no JS workflow runtime. Instead:

- Run the audit's steps inline with `Read`/`Grep`/`Bash`, or fan the independent
  sweeps out with `Agent` (`subagent_type: "explore"`) and merge.
- Write the report to `.claude/reports/harness-legacy-check.md` regardless — the
  path is the contract `harness:harness-refactor` reads from.
- For `harness-refactor`, still generate `.claude/workflows/harness-refactor.js`
  (it is the reviewable plan and a Claude Code session can execute it later),
  then apply its low-risk edits yourself with `Edit`.

**No Claude Code built-in catalog.** `harness:dissect-builtin` Step 1 loads a
Claude Code built-in's raw prompt with `Skill(skill: "<name>")`. Kimi cannot
reach Claude Code's built-ins. Run that skill from Claude Code.

**Plugin cache belongs to Claude Code.** `harness:plugin-guide` scans
`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/cache/`. Kimi can read the tree if
Claude Code is installed on the same machine; otherwise the skill has no input
and should stop rather than invent one.

## Read-only and confirmation contracts

- `harness:harness-legacy-check` and `harness:ai-context check` are read-only.
  Never call `Write`, `Edit`, or a mutating `Bash` command from them.
- `harness:ai-context create` / `refactor`, `harness:harness-refactor`, and any
  `--force` overwrite must confirm through `AskUserQuestion` first. Render the
  choice as a real `AskUserQuestion` call, not as plain assistant text — unless
  `AskUserQuestion` is unavailable or the session is in auto permission mode.
