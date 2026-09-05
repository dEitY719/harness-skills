# Plugin-root resolution

A skill often has to read a file that ships inside its own plugin: a vendored
`lib/vendor/shell-common/functions/*.sh`, a bundled `skills/<name>/scripts/*.sh`,
a `references/*.sh.md` block it extracts and sources. `${CLAUDE_PLUGIN_ROOT}` is
the only mechanism the `dEitY719/*-skills` family uses to find that root, and
**only Claude Code sets it**. On Codex, Gemini CLI, Antigravity, Kimi, Hermes and
OpenCode it is empty.

This file is the single answer for all six. It is owned here and linked from the
sibling repos — do not grow a second idiom locally.

## The decision

`CLAUDE_PLUGIN_ROOT` is a **contract**, not a Claude Code feature. It names the
directory the plugin was installed into. Claude Code fills it automatically. On
the other five harnesses **the agent fills it**, from the path it read the
`SKILL.md` at — that path is always known, because reading the skill is how the
run started:

```bash
export CLAUDE_PLUGIN_ROOT=~/.codex/plugins/gh-pr-skills   # or wherever you read SKILL.md from
```

Keeping the Claude Code name is deliberate. Roughly fifty source sites across
five sibling repos already spell it that way and on Claude Code it costs nothing;
a harness-neutral rename would buy nothing and touch every one of them.

## Resolution order

Apply the first tier that yields a directory you have **proved** holds the file
you want.

| # | Tier | Available to |
|---|------|--------------|
| 1 | An override the skill documents by name (`$DOTFILES_ROOT`, `$GH_VERIFY_ROOT`) | everything |
| 2 | `$CLAUDE_PLUGIN_ROOT`, when non-empty | everything |
| 3 | The asking file's own directory, trimmed by its known suffix | a file on disk only |
| 4 | `$PWD`, when the checkout genuinely is the working directory | a maintainer's own clone |
| 5 | **Stop, naming the path tried and the way out** | everything |

There is no tier that guesses. Tier 5 is a real tier, and skipping it is what
produced the `/lib/vendor/shell-common` defect below.

## Which tiers you get depends on the carrier, not the harness

Two wave-1 reviews reached opposite verdicts on the tier-3 self-path idiom. Both
were right: they were looking at different carriers.

**A file on disk that the harness executes or sources** — `lib/*.sh`,
`skills/*/scripts/*.sh`, `.opencode/plugins/harness.js`,
`.hermes-plugin/__init__.py`. It can locate itself, so it gets tier 3. Every
language has the idiom: `$0` / `${BASH_SOURCE[0]}` in shell, `import.meta.url` in
JS, `__file__` in Python. This is the accepted fix in `gh-issue-skills#11`, and
both of this repo's own non-Claude entry points already do it.

**A block the agent pastes into a shell** — a fenced `bash` block inside a
`SKILL.md` or a `references/*.sh.md`. It has no self: `$0` is the shell (`-zsh`,
`/bin/bash`) and `BASH_SOURCE` is unset, so tier 3 does not exist for it. This is
why the same idiom was correctly rejected in `gh-pr-skills#15`. A pasted block
gets tiers 1, 2, 4, 5 and nothing else — and on a harness where nobody exported
the variable and the cwd is not the checkout, **tier 5 is the answer**:
unsupported, fail loudly.

**The agent reading a file itself** (`read_file("<root>/skills/x/SKILL.md")`) is
not a path-resolution problem at all. The agent already holds the root; that is
exactly the value tier 2 wants it to export.

## Canonical form — pasted block

The shape every `github-target.md` / `board-sync-*.md` site should converge on:

```sh
_SC="${DOTFILES_ROOT:-$HOME/dotfiles}/shell-common"                                  # tier 1
[ -f "$_SC/functions/gh_host.sh" ] || _SC="${CLAUDE_PLUGIN_ROOT:-$PWD}/lib/vendor/shell-common"   # tiers 2, 4
[ -f "$_SC/functions/gh_host.sh" ] || {                                             # tier 5
    printf '[gh-pr:merge] shell-common not found under %s. On Claude Code this is a broken install; on any other harness export CLAUDE_PLUGIN_ROOT=<plugin dir> first.\n' \
        "$_SC" >&2
    exit 1
}
export SHELL_COMMON="$_SC"
```

Three things are load-bearing:

- `:-$PWD`, never `:-}`. A non-empty default is what keeps tier 2 from
  collapsing to the filesystem root.
- The **second** `[ -f ]`. It is not a duplicate: the first selects a tier, the
  second proves the selection before anything downstream trusts it.
- `export` sits after the proof, never inside the fallback branch.
- The skill name in the message is a literal, not a `$VAR` these blocks do not
  bind — an unbound name printing empty is the same class of bug.

Use `return 1` instead of `exit 1` in a file that is sourced rather than pasted.

## Canonical form — a `.sh` file that can locate itself

Prefer this: move the block into `lib/<name>.sh` and let the pasted block shrink
to one `.` line. `gh-issue-skills#11`'s `lib/resolve-target.sh` is the reference
implementation.

```sh
# MUST stay at file top level. zsh rebinds $0 to the sourced file only for this
# file's own statements; inside a function $0 is the function's name. dash has
# neither, and aborts on ${BASH_SOURCE[0]} unless $BASH_VERSION gates it.
if [ -n "${ZSH_VERSION-}" ]; then
    _self="$0"
elif [ -n "${BASH_VERSION-}" ]; then
    # shellcheck disable=SC3028
    _self="${BASH_SOURCE[0]-}"
else
    _self=""
fi

_root="${CLAUDE_PLUGIN_ROOT:-}"                                  # tier 2
if [ -z "$_root" ]; then
    case "$_self" in                                             # tier 3
        */lib/resolve-target.sh) _root="${_self%/lib/resolve-target.sh}" ;;
        *)                       _root="$PWD" ;;                 # tier 4
    esac
fi
```

Match the suffix with `case`, never `dirname` on an unvalidated `$_self` — the
pattern failing is how tier 3 declines instead of inventing a path.

zsh and bash reach tier 3; `dash` and `sh` have no self-path at all and land on
tier 4, whose `[ -f ]` proof then sends them to tier 5. Tier 3 is a bonus, never
a guarantee — the proof is what holds.

Both snippets on this page are asserted by
[`plugin-root.selfcheck.sh`](plugin-root.selfcheck.sh), which runs them across
every shell present and checks that tier 5 stops, names the resolved path, and
exports nothing. Run it before changing either snippet, and copy its tier-5 case
into a rollout PR's test plan.

## Rule: never concatenate a possibly-empty variable into a path

`gh-resolve-skills#8` found the cost. With `CLAUDE_PLUGIN_ROOT` unset,

```sh
_SC="${CLAUDE_PLUGIN_ROOT:-}/lib/vendor/shell-common"; export SHELL_COMMON="$_SC"
```

resolves to `/lib/vendor/shell-common` — the filesystem root — and then
**exports** it, so every later `${SHELL_COMMON:-$HOME/dotfiles/shell-common}`
lookup in that run reads the poisoned value instead of its own default. One
missing character silently disabled a whole run's helper resolution, and two
reviewers passed it.

Banned, in shell and in a fenced block alike:

- `"${VAR:-}/..."` and `"${VAR-}/..."` — an explicitly empty default spliced into a path
- `"$CLAUDE_PLUGIN_ROOT/..."` — no default at all
- `export`ing any path before an `[ -f ]` / `[ -r ]` has proved it

Allowed: a non-empty default (`${VAR:-$PWD}`, `${VAR:-.}`), or bind-then-guard
(`_root="${VAR:-}"; [ -n "$_root" ] || <tier 3/4/5>`).

One grep is the gate. It has no false positives — an explicitly empty default
immediately followed by `/` is always the defect, and neither
`${CLAUDE_PLUGIN_ROOT:-$PWD}/...` nor a guarded `[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]`
matches it:

```sh
grep -rnE '\$\{[A-Za-z_][A-Za-z0-9_]*:?-\}/' skills lib   # must return nothing
```

A second grep is a review prompt, not a gate, because it cannot see the guard:

```sh
grep -rnE '\$\{?CLAUDE_PLUGIN_ROOT\}?/' skills lib
```

Every hit must sit inside a proof that already ran — `[ -n "$VAR" ]` or a
`[ -f ]` on the composed path. Read them; do not "fix" a guarded one.

## Per-harness answers

| Harness | Sets a variable | Where the plugin lands | What a pasted block must do |
|---|---|---|---|
| Claude Code | `CLAUDE_PLUGIN_ROOT` | plugin cache | nothing — tier 2 hits |
| Codex | no | `~/.codex/plugins/` (`codex-tools.md`) | export `CLAUDE_PLUGIN_ROOT` first, else tier 5 |
| Gemini CLI | no | the extension dir it loaded `GEMINI.md` from | same |
| Antigravity | no | shares Gemini CLI's `~/.gemini` install | same |
| Kimi CLI | no | the install dir named by `.kimi-plugin/plugin.json` | same |
| Hermes | no | `~/.hermes/plugins/<repo>/` (`hermes-tools.md`) | same |
| OpenCode | no | OpenCode's plugin manager dir | same |

No non-Claude harness exports an equivalent variable, and none is expected to.
That is the whole reason tier 5 exists rather than a sixth clever fallback.

## Not this question

Whether `.claude-plugin/plugin.json` exists at all (`authoring-skills#9`) is a
neighbouring problem, not this one: a manifest-less personal skill tree has no
plugin root to resolve. It gets the same tier-5 answer and is tracked separately.

## Evidence

- `claudecode-skills#5` — a bundled script invoked by a repo-relative path never
  ran for a marketplace install; fixed with `${CLAUDE_PLUGIN_ROOT:-.}` (tier 2
  into tier 4).
- `gh-issue-skills#11` — tier 3 accepted for a sourced `lib/*.sh`.
- `gh-pr-skills#15` — tier 3 rejected for a pasted block; loud `[FAIL]` instead.
- `gh-resolve-skills#8` — the `/lib/vendor/shell-common` export.
