# Templates — harness:ai-context create

The `create` action picks one of these templates from `--type` and the
`size_class` that `../../scripts/detect-context.sh` reports. The thresholds
behind `size_class` are the script's; this page only maps the answer to a file,
so that tuning them is one edit.

| `--type` | `size_class` | Template             |
|----------|--------------|----------------------|
| agents   | `small`      | `agents-small.md`    |
| agents   | `medium`     | `agents-medium.md`   |
| agents   | `large`      | `agents-large.md`    |
| claude   | `simple`     | `claude-simple.md`   |
| claude   | `standard`   | `claude-standard.md` |
| claude   | `large`      | `claude-large.md`    |

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
