# Shared per-harness tool mappings

Skills in the `dEitY719/*-skills` family speak in **actions** ("read a file",
"dispatch a subagent", "run a workflow", "ask the user"). Every harness names
those tools differently. These six files are the mapping.

| File | Harness |
|------|---------|
| [`codex-tools.md`](codex-tools.md) | Codex CLI / Codex App |
| [`kimi-tools.md`](kimi-tools.md) | Kimi CLI (Kimi Code) |
| [`gemini-tools.md`](gemini-tools.md) | Gemini CLI |
| [`antigravity-tools.md`](antigravity-tools.md) | Antigravity (`agy`) |
| [`hermes-tools.md`](hermes-tools.md) | Hermes Agent |
| [`opencode-tools.md`](opencode-tools.md) | OpenCode |

Claude Code has no file here: the skills are written in Claude Code's
vocabulary, so on Claude Code the mapping is the identity.

## Ownership (dotfiles #1410 F-5 / NF-2)

**This repo is the sole owner.** The other fourteen `*-skills` repos declare
`harness@harness-skills` as a dependency and link here; they do **not** carry
copies. One tool rename would otherwise mean fifteen edits, and the fifteenth
is the one that gets forgotten. If you are about to paste one of these files
into another repo, stop — add a link instead.

The Kimi mapping is additionally mirrored, in condensed form, into this repo's
`.kimi-plugin/plugin.json` `skillInstructions` field, because Kimi CLI has no
mechanism for reading a reference file at load time. That field points back
here as the source of truth; keep it short and keep this file authoritative.

## How to read one

Do not read all six. Read the one for the harness you are running, and read it
lazily — when a skill names a tool you do not recognise, or when it asks for a
capability (a workflow runtime, a built-in skill loader) that your harness may
not have. Each file ends with a "Capability gaps" section listing what the
harness cannot do and what to do instead; that section is the important part.

## What lives here vs. in a skill

These files describe **the harness**. They never describe what a skill does —
that belongs in the skill's own `SKILL.md` and `references/`. If you find
yourself writing "the ai-context skill then ..." in one of these files, it is
in the wrong place.
