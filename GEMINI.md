# harness — skill index

Five skills for managing the AI coding harness itself. Each lives in this
extension's `skills/` directory. They are task-triggered: load the one that
matches the job by reading its `SKILL.md`, then follow it. Do not load all five.

| Skill | Read | Use when |
|-------|------|----------|
| `ai-context` | `@./skills/ai-context/SKILL.md` | Auditing, authoring, or splitting a `CLAUDE.md` / `AGENTS.md` / `GEMINI.md`. Not for `SKILL.md` or `*.sh`. |
| `harness-legacy-check` | `@./skills/harness-legacy-check/SKILL.md` | Auditing the whole harness read-only — context docs, skills, workflows, settings, hooks, MCP. Writes a report, changes nothing. |
| `harness-refactor` | `@./skills/harness-refactor/SKILL.md` | Applying the low-risk findings from that report. Run the check first. |
| `dissect-builtin` | `@./skills/dissect-builtin/SKILL.md` | Documenting a Claude Code built-in skill. Requires Claude Code — see the gap note below. |
| `plugin-guide` | `@./skills/plugin-guide/SKILL.md` | Documenting an installed Claude Code plugin from its cached `SKILL.md` files. |

Each skill's `references/` directory holds the detail it loads on demand;
`SKILL.md` says which file to read and when. Do not read `references/` files up
front.

## Tool mapping for Gemini CLI

The skills speak in actions. On Gemini CLI these resolve to:

- "Read a file" -> `read_file` / `read_many_files`
- "Create a file" / "edit a file" -> `write_file`, `replace`
- "Run a shell command" -> `run_shell_command`
- "Search file contents" -> `grep_search`
- "Find files by name" -> `glob`
- "Create a todo" -> `write_todos`
- "Ask the user" -> `ask_user`
- "Dispatch a subagent" -> `invoke_agent` with `agent_name: "generalist"`

The full mapping, including every capability gap and its workaround, is
`@./references/gemini-tools.md`. Read it when a skill names a tool you do not
recognise. On Antigravity read `@./references/antigravity-tools.md` instead —
`agy` shares `~/.gemini` but not Gemini CLI's tool names.

## Capability gaps on Gemini CLI

- `harness-legacy-check` and `harness-refactor` call Claude Code's `Workflow`
  tool. Gemini has no workflow runtime: run their steps directly, but keep the
  output contract — the report goes to
  `.claude/reports/harness-legacy-check.md`, and `harness-refactor` still writes
  `claude/workflows/harness-refactor.js` as the plan of record.
- `dissect-builtin` loads a Claude Code built-in's raw prompt. Gemini cannot
  reach those; run that skill from Claude Code.
- `plugin-guide` reads Claude Code's plugin cache
  (`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/cache/`). Works only where
  Claude Code is installed on the same machine.

## Safety rules

- `harness-legacy-check` and `ai-context check` are strictly read-only. Never
  write, edit, or run a mutating shell command while following them.
- `ai-context create` / `refactor` and `harness-refactor` present a plan and
  wait for confirmation before writing. Use `ask_user`; an auto-approve session
  setting is not the user's answer.
- `plugin-guide` never installs a plugin and never commits.
