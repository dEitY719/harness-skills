# Antigravity (`agy`) Tool Mapping

Skills speak in actions. On the Antigravity CLI these resolve to the tools
below. Read this file when a skill names a tool you do not recognise.

Antigravity shares `~/.gemini` with Gemini CLI, so a
`gemini extensions install https://github.com/dEitY719/harness-skills` makes
this plugin visible in both. The **install** is shared; the **tool names are
not**. Do not carry Gemini CLI's tool names over — see
[`gemini-tools.md`](gemini-tools.md) for that side.

## Tools

| Action skills request | Antigravity equivalent |
|---|---|
| Read a file | `view_file` |
| Create a file | `write_to_file` |
| Edit a file | `replace_file_content`, `multi_replace_file_content` |
| Run a shell command | `run_command` |
| Search file contents | `grep_search` |
| Find files by name | `find_by_name` |
| List a directory | `list_dir` |
| Task tracking (`TodoWrite`) | a **task artifact** — see below. **Not** `manage_task`. |
| Ask the user / confirm | Ask in the conversation and wait for the reply |
| Dispatch a subagent | `invoke_subagent` with `TypeName: "self"` (full capability) or `"research"` (read-only) |
| Invoke a skill | Read the `SKILL.md` directly; there is no skill namespace |

Antigravity exports no plugin-root variable. When a skill hands you a shell
block that reads `${CLAUDE_PLUGIN_ROOT}`, `export` it yourself to the directory
you read the `SKILL.md` from, before running the block — otherwise the block
stops rather than guessing. Full rule:
[`plugin-root.md`](plugin-root.md).

## Task tracking

Antigravity has **no todo tool**. `manage_task` manages background processes
(`list` / `kill` / `status` / `send_input`) and is not a checklist — reaching
for it when a skill says "create a todo" is the classic mistake here.

Instead maintain a **task artifact**: a markdown checklist written with
`write_to_file` (`IsArtifact: true`, `ArtifactMetadata.ArtifactType: "task"`)
and updated with `replace_file_content` as you go. Create it at the start of any
multi-step run, mark each step `- [x]` as it completes, and re-read it before
each step once the conversation gets long.

This matters most for `harness:harness-refactor`, which applies a classified
list of low-risk fixes: the artifact is what keeps "which findings are already
applied" straight across a long run.

## Subagent dispatch

`invoke_subagent` with a built-in `TypeName`:

- `"research"` for read-only sweeps — fanning out the
  `harness:harness-legacy-check` audit across `skills/`, hooks, settings, and
  workflows.
- `"self"` for children that write — `harness:dissect-builtin`'s
  documentation-writing agent.

## Progressive disclosure

Skills say "read `references/checks.md`" and mean it literally: `view_file` that
path, relative to the skill's own directory, **at the step that names it**. Do
not preload a skill's whole `references/` tree; that defeats the design these
repos were split up to serve.

## Capability gaps

**No workflow runtime.** `harness:harness-legacy-check` calls
`Workflow({ name: 'harness:harness-legacy-check' })` and `harness:harness-refactor`
calls `Workflow({ name: 'harness:harness-refactor', args: { changes: [...], rejected: [...] } })`. Those
are Claude Code tools; Antigravity has neither the tool nor the JS runtime.

- Run the audit's sweeps directly, or fan them out with
  `invoke_subagent {TypeName: "research"}`, and merge.
- Write the report to `.claude/reports/harness-legacy-check.md` regardless —
  that path is the contract `harness:harness-refactor` reads from.
- For `harness-refactor`, still write `.claude/workflows/harness-refactor.js`
  (the reviewable plan for a human to read — Claude Code's own skill passes its
  change list through `Workflow` `args`, not this file, so a later Claude Code
  session will not execute it), then apply its low-risk edits yourself with
  `replace_file_content`.

**No Claude Code built-in catalog.** `harness:dissect-builtin` Step 1 loads a
Claude Code built-in's raw prompt with `Skill(skill: "<name>")`. Antigravity
cannot reach those. Run that skill from Claude Code, or supply the prompt text
by hand and start at Step 2.

**Plugin cache belongs to Claude Code.** `harness:plugin-guide` scans
`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/cache/`. Readable via `run_command`
when Claude Code is installed on the same machine; otherwise the skill has no
input and should stop.

## Read-only and confirmation contracts

- `harness:harness-legacy-check` and `harness:ai-context check` are strictly
  read-only. Never call `write_to_file`, `replace_file_content`, or a mutating
  `run_command` while following them — including to create the task artifact
  mid-audit; write the artifact before you start, or skip it.
- `harness:ai-context create` / `refactor` and `harness:harness-refactor` print
  a plan and **wait**. With no structured question tool, state the plan, ask,
  and end your turn.
