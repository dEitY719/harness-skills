# Hermes Agent Tool Mapping

Skills speak in actions. On Hermes Agent these resolve to the tools below. Read
this file when a skill names a tool you do not recognise.

## Tools

| Action skills request | Hermes tool |
|---|---|
| Read a file | `read_file` |
| Create a file | `write_file` |
| Edit a file (targeted patch) | `patch` |
| Run a shell command | `terminal` |
| Search file contents | `search_files` |
| Find files by name | `terminal` with `find` |
| Fetch a URL | `web_extract(urls=[...])` |
| Search the web | `web_search(query=...)` |
| Task tracking (`TodoWrite`) | the `todo` tool |
| Ask the user / confirm | Ask in the conversation and wait for the reply |
| Dispatch a subagent | `delegate_task(goal=..., context=..., toolsets=[...], role="leaf")` |
| Invoke a skill | `skill_view("<name>")` |

## Invoking a skill

Hermes has a native `skills` toolset (`skills_list`, `skill_view`). After
`hermes plugins install dEitY719/harness-skills`, this repo's
`.hermes-plugin/__init__.py` registers all five under their bare names:

```
skill_view("ai-context")
skill_view("harness-legacy-check")
```

If `skill_view` cannot find one (the catalog may lag plugin registration), fall
back to reading the file directly:

```
read_file(path="~/.hermes/plugins/harness-skills/skills/<name>/SKILL.md")
```

If registration failed outright, `__init__.py` raises loudly rather than
silently skipping — a bootstrap that skips quietly is how a broken install
passes for a working one. Read the error; it prints the paths it tried.

Hermes exports no plugin-root variable. When a skill hands you a shell
block that reads `${CLAUDE_PLUGIN_ROOT}`, `export` it yourself to the directory
you read the `SKILL.md` from, before running the block — otherwise the block
stops rather than guessing. Full rule:
[`plugin-root.md`](plugin-root.md).

## Progressive disclosure

`skill_view` returns the `SKILL.md` only. When a step says "read
`references/help.md`", `read_file` that path relative to the skill's directory
**at that step** — not up front.

## Subagent dispatch

`delegate_task` with `role="leaf"`:

- `harness:dissect-builtin` Step 2 wants ONE child (the README.md writer); the
  parent writes PROMPT.md itself. Issue a single `delegate_task` call, carrying
  both the brief and the raw prompt text.
- The `harness:harness-legacy-check` audit's independent sweeps (context docs,
  skills, workflows, settings, hooks, MCP) fan out the same way.

If `delegate_task` is unavailable, do the work inline rather than inventing tool
calls.

## Instructions file

When a skill says "your instructions file", on Hermes that is `AGENTS.md` in the
project directory, or `SOUL.md` globally at `~/.hermes/SOUL.md`. This matters
for `harness:ai-context`: its auto-detect order is `CLAUDE.md` -> `AGENTS.md` ->
`GEMINI.md`, so in a Hermes-only repo it will land on `AGENTS.md`, which is the
right target. `SOUL.md` is **not** in the detect list — pass it explicitly with
`--file ~/.hermes/SOUL.md --type agents` if you want it audited.

## Capability gaps

**No workflow runtime.** `harness:harness-legacy-check` calls
`Workflow({ name: 'harness:harness-legacy-check' })` and `harness:harness-refactor`
calls `Workflow({ scriptPath: '.claude/workflows/harness-refactor.js' })`. Those
are Claude Code tools backed by a JS runtime Hermes does not have.

- Run the audit's sweeps with `read_file` / `search_files` / `terminal`, or fan
  the independent ones out with `delegate_task`.
- Write the report to `.claude/reports/harness-legacy-check.md` regardless —
  that path is the contract `harness:harness-refactor` reads from.
- For `harness-refactor`, still write `.claude/workflows/harness-refactor.js`:
  the reviewable plan of record, executable later from Claude Code. Then apply
  its low-risk edits yourself with `patch`.

**No Claude Code built-in catalog.** `harness:dissect-builtin` Step 1 loads a
Claude Code built-in's raw prompt with `Skill(skill: "<name>")`. Hermes'
`skill_view` resolves Hermes' own skill catalog, not Claude Code's built-ins.
Run that skill from Claude Code, or supply the prompt by hand and start at
Step 2.

**Plugin cache belongs to Claude Code.** `harness:plugin-guide` scans
`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/cache/<marketplace>/<plugin>`;
Hermes' own plugins live under `~/.hermes/plugins/`. The skill documents Claude
Code plugins specifically, so point it at the Claude tree (readable via
`terminal` if Claude Code is installed here) — do not silently retarget it at
`~/.hermes/plugins/`, which has a different layout and would produce a doc that
claims to describe something it does not.

## Read-only and confirmation contracts

- `harness:harness-legacy-check` and `harness:ai-context check` are strictly
  read-only. Never call `write_file`, `patch`, or a mutating `terminal` command
  while following them.
- `harness:ai-context create` / `refactor` and `harness:harness-refactor` print
  a plan and **wait**. With no structured question tool, state the plan, ask,
  and end your turn.
