# Templates — harness:ai-context create

The `create` action picks one of these templates based on `--type` and the
size discovered during `Phase 0`.

## agents (AGENTS.md)

| Size   | Heuristic                              | Template            |
|--------|----------------------------------------|---------------------|
| small  | < 20 files, single tech stack          | `agents-small.md`   |
| medium | 20–100 files, 2–3 tech domains         | `agents-medium.md`  |
| large  | 100+ files, multiple services          | `agents-large.md`   |

## claude (CLAUDE.md, orchestrator)

| Size     | Heuristic                  | Template             |
|----------|----------------------------|----------------------|
| simple   | 1–2 agents, single domain  | `claude-simple.md`   |
| standard | 3–6 agents, multi-domain   | `claude-standard.md` |
| large    | 7+ agents, enterprise      | `claude-large.md`    |

## gemini (GEMINI.md)

No native template yet. Use `agents-{size}.md` and adapt the front matter
to Gemini's hierarchy / import / `.geminiignore` model — see
`../industry-baseline.md` for the deltas.

When a Gemini-native template lands, add a `gemini-{size}.md` file here
and update this README.

---

## Why the `claude-*` templates stay (harness-skills#3)

Claude Code ships `/init`, which bootstraps a CLAUDE.md and overlaps these
three templates. They are kept anyway: `/init` is a Claude Code built-in, and
this plugin ships to six harnesses (see the repo-root `references/*-tools.md`),
five of which have no equivalent. Deleting them would leave
`create --type claude` working on Claude Code only.

On Claude Code, running `/init` first and then `harness:ai-context check
--type claude` against its output is the better path; these templates are the
portable fallback, not a competitor. Do not re-file this as dead code.
