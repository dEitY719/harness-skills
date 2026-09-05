# harness:plugin-guide — Help

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `<plugin-name>` | Positional 1 — `<plugin>@<marketplace>` or `<plugin>` alone; required unless help | — |
| `[output-root]` | Positional 2 — directory the guide and its index are written under; created if absent | `docs/guide/plugins` |
| `--force` | Regenerate the doc even if it already exists | off |
| `-h` / `--help` / `help` | Print this help and stop; no file reads/writes | — |

## Usage

- `/harness:plugin-guide ponytail@ponytail` — generate `docs/guide/plugins/ponytail.md`
- `/harness:plugin-guide andrej-karpathy-skills` — marketplace inferred from the installed-plugin record
- `/harness:plugin-guide ponytail docs/plugins` — write under a different output root
- `/harness:plugin-guide ponytail --force` — overwrite an existing doc
- `/harness:plugin-guide -h` / `--help` / `help` — print this help

## What the skill does

1. Confirms the plugin is a key of `$CFG/plugins/installed_plugins.json`'s
   `plugins` object — Claude Code's own installed-plugin record, where
   `CFG=${CLAUDE_CONFIG_DIR:-$HOME/.claude}` (SSOT). If not installed, prints the
   설치 안내 below and stops — never installs for you.
2. Finds every `skills/*/SKILL.md` under the plugin's cache dir
   (`$CLAUDE_CONFIG_DIR/plugins/cache/<marketplace>/<plugin>/<version>/`),
   picking the highest version. Zero skills → reports "스킬 없음" and stops.
3. Extracts each skill's `name` / `description` + one core rule.
4. Writes `<output-root>/<plugin>.md` in Korean with 3 fixed sections:
   설치 방법 / 스킬 설명 / 사용법 예제.
5. Adds an idempotent index line to `<output-root>/README.md`, creating that
   file with an `## Index` heading if it does not exist yet.
6. Existing doc + no `--force` → skips (safe re-run). `--force` overwrites.

## What the skill will NOT do

- Install plugins, run `/plugin install`, or add marketplaces (Non-Goal).
- Commit or open a PR — it stops after writing the doc.
- Smoke-test the skills — out of scope.
- Merge/diff sections into an existing doc — it either skips or overwrites.

## 설치 안내 (not-installed error case, filled per plugin)

```
플러그인 <plugin>@<marketplace> 이 설치되어 있지 않습니다. 설치 후 재실행하세요:

/plugin marketplace add <owner/repo>
/plugin install <plugin>@<marketplace>
/reload-plugins
```

`<owner/repo>` comes from `$CFG/plugins/known_marketplaces.json`'s
`[<marketplace>].source.repo`.

## 출력 형식 (final report)

```
[OK] <output-root>/<plugin>.md 생성 (스킬 N개)
- <output-root>/README.md 인덱스 갱신
Next: 문서 검토 후 /gh-pr:commit 으로 커밋 (이 스킬은 커밋하지 않음)
```

Skip case:
```
[SKIP] <output-root>/<plugin>.md 이미 존재 — 재생성하려면 --force
```
