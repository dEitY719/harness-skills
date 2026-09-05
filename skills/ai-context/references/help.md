# harness:ai-context — Help

## Synopsis

```
/harness:ai-context [action] [path]
/harness:ai-context [action] [--file PATH] [--type TYPE]
/harness:ai-context -h | --help | help
```

## Description

Single entry point for AI context-injection files (`CLAUDE.md`, `AGENTS.md`,
`GEMINI.md`). Replaces five legacy skills:

- `agents-md:check`
- `agents-md:create`
- `agents-md:refactor`
- `claude-md-check`
- `claude-md-create`

The legacy skills have been deleted (follow-up to dEitY719/dotfiles#539, see
issue dEitY719/dotfiles#560).

## Actions

| Action     | Behavior                                                     |
|------------|--------------------------------------------------------------|
| `check`    | (default) Audit the target file; never mutate                |
| `create`   | Generate a new context file from a template (with confirmation) |
| `refactor` | Slim and split an existing file (with confirmation)          |
| `help`     | Print this page and stop                                     |

## Arguments

| Arg            | Description                                       | Default       |
|----------------|---------------------------------------------------|---------------|
| `action`       | `check` / `create` / `refactor` / `help`          | `check`       |
| `path`         | Explicit target file path                         | auto-detect   |
| `--file PATH`  | Same as positional `path`; takes precedence       | —             |
| `--type TYPE`  | Force adapter: `agents` / `claude` / `gemini`     | from filename |
| `-h`/`--help`  | Print this help and stop                          | —             |

Auto-detection priority in cwd: `CLAUDE.md` → `AGENTS.md` → `GEMINI.md`.
Aliases of one source collapse first: two names on the same inode (a
`CLAUDE.md` -> `AGENTS.md` symlink), or a `CLAUDE.md` that only imports
`@AGENTS.md`, count as one file. When genuinely distinct files coexist, only the
highest-priority one is audited — pass the path explicitly to target another.

## Examples

```
/harness:ai-context check AGENTS.md              # explicit target (when CLAUDE.md also exists)
/harness:ai-context check CLAUDE.md              # explicit target
/harness:ai-context                               # auto-detect (recommended only when one file exists)
/harness:ai-context check --file ./docs/AGENTS.md  # check a non-root path
/harness:ai-context create --type agents          # walk through new-AGENTS.md flow
/harness:ai-context create --type claude          # walk through new-CLAUDE.md flow
/harness:ai-context refactor                      # plan + execute split on confirm
/harness:ai-context help                          # this page
```

## Stop conditions

- No context file found and action is `check`/`refactor` → suggest `create`.
- Multiple files found and action is `create`/`refactor` → prompt; never auto-overwrite.
- Target is unreadable → abort with the underlying error.
- Target is `SKILL.md` → route to `authoring:skill-check`.
- Target is `*.sh` → route to `authoring:sh-check`.

## Migration from legacy skills

| Legacy command                 | New command                                |
|--------------------------------|--------------------------------------------|
| `/agents-md:check [path]`      | `/harness:ai-context check [path]`            |
| `/agents-md:create`            | `/harness:ai-context create --type agents`    |
| `/agents-md:refactor`          | `/harness:ai-context refactor --type agents`  |
| `/claude-md-check [path]`      | `/harness:ai-context check [path]`            |
| `/claude-md-create`            | `/harness:ai-context create --type claude`    |

Legacy skill directories have been removed (issue dEitY719/dotfiles#560) — use the commands above.

## Output

See `references/report-template.md` for the canonical report layout.
Verdict is `[OK]` if no check fails, else `[FAIL]`. Always ends with a
`Next:` action hint.
