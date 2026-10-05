---
name: plugin-guide
description: >-
  Generate a Korean guide doc for an installed Claude Code plugin from its
  cached SKILL.md files, then update the plugins index. Use for
  /harness:plugin-guide <plugin-name>, "플러그인 가이드 만들어줘",
  "플러그인 문서화해줘". Does NOT install plugins and does NOT commit.
license: MIT
allowed-tools: Bash, Read, Grep, Write, Edit
metadata:
  model_recommendation:
    tier: sonnet
    reason: "parses N SKILL.md frontmatters + builds a structured Korean doc; low-risk doc writes, no code changes"
    claude: prefer
    non_claude: advisory-only
---

# harness:plugin-guide — Plugin Guide Generator

## Help

If arg #1 is `-h`, `--help`, or `help`, read `references/help.md` and output
its content verbatim, then stop. No file reads/writes.

## Step 1: Parse Args

Positional: `<plugin-name> [output-root] [--force]`.

| Arg | Description | Default | Required |
|-----|-------------|---------|----------|
| `<plugin-name>` | `<plugin>@<marketplace>` or `<plugin>` alone | — | Yes |
| `[output-root]` | Directory the guide and its index live in; a `-`-prefixed token is a flag, never this | `docs/guide/plugins` | No |
| `--force` | Regenerate even if the target doc already exists | off | No |

Split `<plugin-name>` on `@` into `PLUGIN` and (optional) `MARKETPLACE`. The output
filename is always `PLUGIN.md`. Missing arg → print `[FAIL] harness:plugin-guide —
<plugin-name> 누락 (Step 1 args). Run /harness:plugin-guide -h for usage.` and stop.
Set `OUT` = `[output-root]` (create it if absent).

## Step 2: Verify Installed (F-2)

Resolve with the bundled script — an exact `id` match via `jq`, never a substring `grep`:

```bash
_lib=""
if [ -n "${HERMES_SKILL_DIR}" ]; then _lib="${HERMES_SKILL_DIR}/lib"
elif [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then _lib="$CLAUDE_PLUGIN_ROOT/skills/plugin-guide/lib"
fi
[ -n "$_lib" ] && [ -f "$_lib/resolve-plugin.sh" ] || { printf '[FAIL] plugin root unresolved (tried: %s). Export HERMES_SKILL_DIR=<this skill dir> (single-skill install) or CLAUDE_PLUGIN_ROOT=<plugin dir> first.\n' "${_lib:-nothing}" >&2; return 1 2>/dev/null || exit 1; }
sh "$_lib/resolve-plugin.sh" "<plugin-name>"
```

Exit 0 → bind `MARKETPLACE` / `INSTALL_PATH` from its stdout. Exit 1 (not installed),
2 (ambiguous: relay the ids, ask for `<plugin>@<marketplace>`) and 3 (`jq` or the
Claude-Code-only CLI unavailable — never "not installed"; other harnesses: repo-root
`references/*-tools.md`) stop with the messages in `references/marketplace-resolution.md`.

## Step 3: Enumerate Skills (F-3)

Run `find "$INSTALL_PATH" -maxdepth 4 -iname SKILL.md` (already the resolved version).

Zero `SKILL.md` found → this is the **no-skills error case**: print `[FAIL]
harness:plugin-guide — 스킬 없음, 문서화 대상 아님 (Step 3 skills)` and stop. If skill
count > 10, print ONE warning line (`스킬 N개 (>10) — YAGNI: 단일 파일로 생성`) and
continue with a single file.

For each `SKILL.md`, read frontmatter `name`/`description` and skim the body for
its one core rule → a 1-2 line "하는 일" summary (see `references/doc-template.md`).

## Step 4: Idempotent Skip (Acceptance: safe re-run)

If `$OUT/<PLUGIN>.md` already exists and `--force` was NOT passed: print
`[SKIP] $OUT/<PLUGIN>.md 이미 존재 — 재생성하려면 --force` and stop. Do NOT
diff or merge sections. `--force` overwrites the file wholesale.

## Step 5: Write the Doc (F-4, F-6)

Write `$OUT/<PLUGIN>.md` in **Korean**, following the exact
3-section skeleton in `references/doc-template.md` (설치 방법 → 스킬 설명 →
사용법 예제). SKILL.md sources are English — summarize, don't copy prose.

## Step 6: Update Index (F-5)

Re-run Step 2's locator (Bash calls share no variables), then relay its one word
(`added` | `skipped`; idempotent, inserts inside `## Index` before the next `## `):
`sh "$_lib/index-insert.sh" "$OUT/README.md" "<PLUGIN>" "<one-line Korean summary>"`

## Step 7: Report

Print the report per `references/help.md` "출력 형식": `[OK]`/`[SKIP]`/`[FAIL]`
verdict, files written/skipped, skill count, and the next step (review the
doc, then commit manually — this skill never commits).

## Constraints

- Never install plugins / run `/plugin install` (F-2 stops for the user), never
  commit or open a PR (Non-Goal), never smoke-test skills (out of scope).
- Generated docs are Korean (docs/AGENTS.md Language Policy); the SKILL.md
  sources stay English — do not confuse the two. No emojis anywhere.
