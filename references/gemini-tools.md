# Gemini CLI Tool Mapping

Skills speak in actions. On Gemini CLI these resolve to the tools below. Read
this file when a skill names a tool you do not recognise.

## Tools

| Action skills request | Gemini CLI equivalent |
|---|---|
| Read a file | `read_file` |
| Read several files at once | `read_many_files` |
| Create a file | `write_file` |
| Edit a file | `replace` |
| Run a shell command | `run_shell_command` |
| Search file contents | `grep_search` (older builds: `search_file_content`) |
| Find files by name | `glob` |
| List a directory | `list_directory` |
| Fetch a URL | `web_fetch` |
| Search the web | `google_web_search` |
| Task tracking (`TodoWrite`) | `write_todos` |
| Ask the user / confirm | `ask_user` (text / single-select / multi-select) |
| Dispatch a subagent | `invoke_agent` with `agent_name: "generalist"` (chat shortcut: `@generalist`) |
| Invoke a skill | `activate_skill`, or an `@./skills/<name>/SKILL.md` include |

Trust your live tool list over this table when they disagree; Gemini CLI renames
tools between releases (`search_file_content` -> `grep_search` is the one that
bites most often).

## Invoking a skill

This repo ships `gemini-extension.json` + `GEMINI.md`. `GEMINI.md` is the index
and names each skill's path. Load one with `activate_skill`, or by include:

```
@./skills/ai-context/SKILL.md
```

Then follow its steps. The `harness:` prefix in skill prose is a naming
convention from other harnesses, not a command to type here.

Gemini CLI exports no plugin-root variable. When a skill hands you a shell
block that reads `${CLAUDE_PLUGIN_ROOT}`, `export` it yourself to the directory
you read the `SKILL.md` from, before running the block — otherwise the block
stops rather than guessing. Full rule:
[`plugin-root.md`](plugin-root.md).

## Progressive disclosure

`GEMINI.md` deliberately lists only the five skills and what each is for. Read
one `SKILL.md`, not all five. Inside a skill, `references/*.md` files load **at
the step that names them** — `@./skills/ai-context/references/checks.md`, and so
on. `read_many_files` makes bulk loading easy, and that is exactly the trap: it
defeats the disclosure design and burns the context these repos were split up to
conserve.

## Subagent dispatch

`harness:dissect-builtin` Step 2 asks for ONE agent, writing `README.md`; the
parent writes `PROMPT.md` itself, because a second model hop can only corrupt a
verbatim copy. Issue a single `invoke_agent` call with
`agent_name: "generalist"`. Fill the skill's prompt text into the call — both
the brief and the raw prompt, since the child inherits neither the plugin path
nor the parent's context.

Keep dependent work sequential, but do not serialize independent agents just to
get a tidier history.

## Capability gaps

**No workflow runtime.** `harness:harness-legacy-check` calls
`Workflow({ name: 'harness:harness-legacy-check' })` and `harness:harness-refactor`
calls `Workflow({ name: 'harness:harness-refactor', args: { changes: [...], rejected: [...] } })`. Those
are Claude Code tools backed by a JS runtime Gemini does not have. Instead:

- Run the audit's sweeps directly (`read_many_files`, `grep_search`,
  `run_shell_command`), or fan the independent ones out with `invoke_agent`.
- Write the report to `.claude/reports/harness-legacy-check.md` regardless. That
  path is the contract `harness:harness-refactor` reads from — nothing about it
  is Claude-specific except the directory name, so keep it.
- For `harness-refactor`, skip writing a plan file. Classify the report the
  same way `references/classification-rules.md` in that skill does, then
  apply each allowed change directly with `replace` / `write_file`, archiving
  the file's current content into
  `.claude/archive/harness-refactor-<YYYY-MM-DD>/<path>` first.
  `workflows/harness-refactor.js` documents the four phases (Pre-flight /
  Apply Changes / Verify / Final Report) if you want the shape, but it is
  written against Claude Code's `Workflow` host and cannot run here. Note
  anything the classification forbids as "Human Approval Required" instead of
  applying it.

**No Claude Code built-in catalog.** `harness:dissect-builtin` Step 1 loads a
Claude Code built-in's raw prompt via `Skill(skill: "<name>")`. `activate_skill`
resolves Gemini's own skills, not Claude Code's built-ins, so Step 1 cannot be
satisfied here. Run that skill from Claude Code, or paste the prompt in by hand
and start at Step 2.

**Plugin cache belongs to Claude Code.** `harness:plugin-guide` scans
`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/cache/<marketplace>/<plugin>` for
`SKILL.md` files. Readable from Gemini CLI with `run_shell_command` when Claude
Code is installed on the same machine; otherwise the skill has no input and
should stop rather than invent one.

## Instructions file

When a skill says "your instructions file", on Gemini CLI that is `GEMINI.md` —
global at `~/.gemini/GEMINI.md`, plus project-level and subdirectory files
loaded hierarchically. This matters for `harness:ai-context`, whose whole job is
auditing and authoring these files: its `gemini` adapter targets `GEMINI.md`,
and `--type gemini` forces that adapter for a non-standard filename.

## Read-only and confirmation contracts

- `harness:harness-legacy-check` and `harness:ai-context check` are strictly
  read-only. Never call `write_file`, `replace`, or a mutating
  `run_shell_command` while following them. `enter_plan_mode` is a convenient
  hard guarantee for the audit.
- `harness:ai-context create` / `refactor` and `harness:harness-refactor` print
  a plan and **wait**. Use `ask_user` for that confirmation. A YOLO /
  auto-approve session setting is not the user's answer.

## Antigravity

Antigravity (`agy`) shares `~/.gemini`, so a `gemini extensions install` here
makes this plugin visible in both. Its tool names differ — see
[`antigravity-tools.md`](antigravity-tools.md).
