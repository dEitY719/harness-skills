# harness:ai-context — Target resolution

The deterministic half of Step 2 lives in `../lib/detect-context.sh`. This page
is what to do with its output.

## Running it

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/ai-context/lib/detect-context.sh" \
  [--file PATH] [--type TYPE] [--dir DIR]
```

`${CLAUDE_PLUGIN_ROOT}` resolves per the repo-root `references/plugin-root.md`.
The script is a file on disk, so tier 3 (self-location) applies to it; if the
root cannot be resolved at all, carry out the three steps below by hand rather
than guessing a path. Detection is cheap — this helper exists to spend the
model's budget on C1–C6 and the adapter checks, not to gate the skill.

## Output fields

| Field              | Meaning                                                    |
|--------------------|------------------------------------------------------------|
| `path`             | The chosen target, by priority `CLAUDE.md` -> `AGENTS.md` -> `GEMINI.md` |
| `kind`             | Adapter to run: `claude` / `agents` / `gemini` (`--type` wins) |
| `content_path`     | The text a reader actually gets — a one-line `@other.md` import is followed |
| `symlink_target`   | Non-empty when `path` is itself a symlink                   |
| `aliases`          | Candidates that are the SAME source as `path` (same inode, or an import shim) |
| `other_candidates` | Candidates that are genuinely distinct files                |
| `line_count`, `c7` | Line count of `content_path` and its C7 verdict (`<=400` PASS, `<=500` WARN, else FAIL) |
| `size_class`       | Template sizing for `create` — see `templates/README.md`     |

Exit status is 1 when no context file exists, so an empty result is never
mistaken for a clean pass.

## Resolution matrix

`aliases` are never counted as extra files. A repo whose `AGENTS.md` is a
symlink to `CLAUDE.md`, or whose `CLAUDE.md` is only `@AGENTS.md`, has ONE
context file — that is the layout Claude Code's own memory docs recommend
(`industry-baseline.md`), so it must not produce a multiple-file WARN. Only
`other_candidates` drives the row below.

| Situation                 | check                                     | create / refactor                       |
|---------------------------|-------------------------------------------|-----------------------------------------|
| `other_candidates` empty  | audit `path`                              | proceed against `path`                  |
| `other_candidates` set    | audit `path`; report the rest as WARN     | print candidates and prompt; never auto |
| exit status 1             | abort with hint: `harness:ai-context create` | proceed (create) / abort (refactor)  |

A non-empty `aliases` list is a PASS signal on adapter check A-CL5
(`checks.md`): every harness reads the same text.

`--type` overrides the filename mapping, for a context file kept under a
non-standard name.
