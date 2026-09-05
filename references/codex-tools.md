# Codex Tool Mapping

Skills speak in actions. On Codex CLI these resolve to the tools below. Read
this file when a skill names a tool you do not recognise.

## Tools

| Action skills request | Codex equivalent |
|---|---|
| Read a file | `read_file` (or `shell` with `cat`) |
| Create a file / edit a file | `apply_patch` |
| Run a shell command | `shell` |
| Search file contents | `shell` with `rg` |
| Find files by name | `shell` with `rg --files` / `find` |
| Task tracking (`TodoWrite`) | `update_plan` |
| Ask the user / confirm | Ask in the conversation and wait for the reply. Codex has no structured question tool. |
| Dispatch a subagent | `spawn_agent` (needs `[features] multi_agent = true` in `~/.codex/config.toml`) |
| Invoke a skill | No skill tool. `read_file` the target `SKILL.md` and follow it. |

## Invoking a skill

Codex has no `Skill()` tool and no skill namespace. `/harness:ai-context` is not
a command you can type. Load a skill by reading its file:

```
read_file(path="<plugin root>/skills/ai-context/SKILL.md")
```

The plugin root is wherever `codex plugin install dEitY719/harness-skills` put
it — check `~/.codex/plugins/`. Follow the file's steps yourself; the `harness:`
prefix in its prose is a naming convention, not something to type.

Codex exports no plugin-root variable, so when a skill hands you a shell block
that reads `${CLAUDE_PLUGIN_ROOT}`, `export` it yourself to the directory you
just read the `SKILL.md` from, before running the block. Full rule, including
what a block must do when you did not:
[`plugin-root.md`](plugin-root.md).

## Progressive disclosure

Skills say "read `references/checks.md`" and mean it literally. Resolve the path
relative to the skill's own directory and `read_file` it **at the step that
names it** — not up front. Codex's context budget is the tightest of the six
harnesses (roughly 2% of the window for skill descriptions), which is the whole
reason these repos are split by domain. Do not preload a skill's `references/`
tree.

## Subagent dispatch

`dissect-builtin` asks for two agents launched in parallel in one message. On
Codex:

```
spawn_agent {fork_turns: "none", model: "...", reasoning_effort: "..."}
```

Set `model` **and** `reasoning_effort` on every spawn — setting `model` alone
silently resets effort to that model's default. `fork_turns: "none"` gives the
child a clean context; the default `"all"` copies your whole transcript, which
for a documentation-writing child is pure waste.

If `multi_agent` is off, do the two writes sequentially in this session. Do not
fabricate a `Task` call.

## Capability gaps

**No workflow runtime.** `harness:harness-legacy-check` calls
`Workflow({ name: 'harness-legacy-check' })` and `harness:harness-refactor`
calls `Workflow({ scriptPath: 'claude/workflows/harness-refactor.js' })`. Codex
has neither tool nor JS runtime for these. Two options, in order of preference:

1. Run the audit inline — the workflow's steps are an ordered read-only sweep of
   `CLAUDE.md`, `AGENTS.md`, `skills/`, `.github/workflows/`, settings, hooks,
   and MCP config. Perform them with `shell` + `read_file` and write the same
   report to `.claude/reports/harness-legacy-check.md`.
2. Fan the independent sweeps out with `spawn_agent` and merge their reports.

Either way the **output contract holds**: the report path is what
`harness:harness-refactor` consumes, so do not relocate or rename it.

For `harness-refactor`, still write `claude/workflows/harness-refactor.js` — it
is the durable, reviewable plan and it is what a Claude Code session will
execute later — then carry out its steps with `apply_patch` yourself.

**No built-in skill catalog.** `harness:dissect-builtin` Step 1 does
`Skill(skill: "<name>")` to load a Claude Code built-in's raw prompt. Codex has
no equivalent and no access to Claude Code's built-ins. Run this skill from
Claude Code, or supply the prompt text by hand and start from Step 2.

**No plugin cache to scan.** `harness:plugin-guide` globs
`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/cache/<marketplace>/<plugin>` for
`SKILL.md` files. That tree is Claude Code's. From Codex you can still read it
if it exists on the same machine — the path is not Codex-specific — but on a
machine with no Claude Code install the skill has no input and should stop.

## Read-only contracts

`harness:harness-legacy-check` and `harness:ai-context check` are audits. Never
reach for `apply_patch` or a mutating `shell` command while following them.
Codex's sandbox may permit the write; the skill still forbids it.

## Confirmation before writes

`harness:ai-context create` / `refactor` and `harness:harness-refactor` all
"wait for confirmation" before writing. With no structured question tool, print
the plan, ask in plain prose, and stop your turn. Do not treat a Codex
auto-approve sandbox setting as the user's answer.
