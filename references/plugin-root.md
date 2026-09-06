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

Apply the first tier that yields a directory you have **proved** loads the file
you want — proved by loading it, not by checking that something is there.

| # | Tier | Available to |
|---|------|--------------|
| 1 | An override the skill documents by name (`$DOTFILES_ROOT`, `$GH_VERIFY_ROOT`) | everything |
| 2 | `$CLAUDE_PLUGIN_ROOT`, when non-empty | everything |
| 3 | The asking file's own directory, trimmed by its known suffix | a file on disk only |
| 5 | **Stop, naming the path tried and the way out** | everything |

There is no tier that guesses. Tier 5 is a real tier, and skipping it is what
produced the `/lib/vendor/shell-common` defect below.

**There is no tier 4.** It used to be `$PWD` — the shape
`claudecode-skills#5` reached for when a bundled script had been invoked by a
repo-relative path and so never ran for a marketplace install
(`${CLAUDE_PLUGIN_ROOT:-.}`, tier 2 falling through to tier 4). `harness-skills#22`
retired it: `$PWD` is caller-controlled, and for most skills in this family it is
**the repository under review** — `gh-pr:review`, `gh-pr:reply`,
`gh-resolve:conflict` and the verify skills all run inside a PR checkout by
design. A hostile pull request that adds
`lib/vendor/shell-common/functions/gh_host.sh` to the target repo supplies the
very file the check is looking for, and gets it sourced by the reviewer's own
tooling. No check helps: anything the target repo can satisfy is not a check —
gating on `$PWD/.claude-plugin/plugin.json` fails for the same reason, since a PR
can add that too. The number is left as a gap rather than reused so that "tier 5"
means the same thing here as it does everywhere else on this page.

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
gets tiers 1, 2, 5 and nothing else — and on a harness where nobody exported the
variable, **tier 5 is the answer**: unsupported, fail loudly. The cwd is not a
consolation prize.

**The agent reading a file itself** (`read_file("<root>/skills/x/SKILL.md")`) is
not a path-resolution problem at all. The agent already holds the root; that is
exactly the value tier 2 wants it to export.

## Canonical form — pasted block

The shape every `github-target.md` / `board-sync-*.md` site should converge on:

```sh
_SC="${DOTFILES_ROOT:-$HOME/dotfiles}/shell-common"                                  # tier 1
if [ ! -f "$_SC/functions/gh_host.sh" ]; then
    [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || {                                            # tier 5
        printf '[gh-pr:merge] no shell-common under %s, and CLAUDE_PLUGIN_ROOT is unset. On Claude Code this is a broken install; on any other harness export CLAUDE_PLUGIN_ROOT=<plugin dir> first.\n' \
            "$_SC" >&2
        return 1 2>/dev/null || exit 1
    }
    _SC="$CLAUDE_PLUGIN_ROOT/lib/vendor/shell-common"                                # tier 2
fi
unset -f _gh_resolve_host 2>/dev/null || :
[ -f "$_SC/functions/gh_host.sh" ] && . "$_SC/functions/gh_host.sh"
command -v _gh_resolve_host >/dev/null 2>&1 || {                                     # tier 5
    printf '[gh-pr:merge] %s did not load a usable shell-common. On Claude Code this is a broken install; on any other harness export CLAUDE_PLUGIN_ROOT=<plugin dir> first.\n' \
        "$_SC" >&2
    return 1 2>/dev/null || exit 1
}
export SHELL_COMMON="$_SC"
```

Six things are load-bearing:

- **Tier 2 is never defaulted into a path.** `[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]`
  guards the assignment instead. That is what keeps tier 2 from collapsing to the
  filesystem root without reaching for a default like `:-$PWD` — see "There is no
  tier 4" above for why that default is not the way out.
- **The `unset -f` / `. ` / `command -v` proof**, converged on over three review
  rounds in `gh-issue-skills#14`. `unset -f` first means the `command -v` after
  the load proves *this* load, in *this* shell, defined the function — not one
  inherited from an earlier block, not a half-sourced file, not a directory
  sitting at that path. It says **nothing** about who put the file there:
  provenance is closed by there being no tier that guesses a root, not by this
  check. An existence test answers "is there a file" and no more, which is why it
  is no longer the last word.
- The `[ -f ]` in front of the `.` is a **load guard, not the proof**. `.` is a
  special built-in, so a missing file aborts a `set -e` `dash`/`sh` outright and
  `|| :` does not catch it. `|| :` on the `unset -f` is likewise for `zsh`, which
  returns non-zero when the function was never defined — the normal case.
- `export` sits after the proof, never inside the fallback branch.
- The skill name in the message is a literal, not a `$VAR` these blocks do not
  bind — an unbound name printing empty is the same class of bug.
- `return 1 2>/dev/null || exit 1`, not a bare `exit 1`. The same text gets
  pasted into a shell *and* sourced from a `references/*.sh.md`, and a bare
  `exit` in the sourced case kills the caller's shell. One form is correct in
  both, so there is only one form to copy.

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
        *)                                                       # tier 5
            printf '[resolve-target] no plugin root: CLAUDE_PLUGIN_ROOT is unset and this shell gives the file no self-path. Export CLAUDE_PLUGIN_ROOT=<plugin dir> first.\n' >&2
            return 1 2>/dev/null || exit 1 ;;
    esac
fi
unset -f _gh_resolve_host 2>/dev/null || :
[ -f "$_root/lib/vendor/shell-common/functions/gh_host.sh" ] \
    && . "$_root/lib/vendor/shell-common/functions/gh_host.sh"
command -v _gh_resolve_host >/dev/null 2>&1 || {                 # tier 5
    printf '[resolve-target] no plugin root: %s holds no usable lib/vendor/shell-common.\n' "$_root" >&2
    return 1 2>/dev/null || exit 1
}
```

The proof is not optional here either. Tier 3 is a real answer — a file that
finds *itself* on disk has provenance, which is exactly what the retired `$PWD`
tier never had — but it is still only a path until something on disk loads from
it, and a sourced file that skips the check carries a wrong root into every
helper the caller sources afterwards — the same blast radius as the poisoned
export, reached a different way.

Match the suffix with `case`, never `dirname` on an unvalidated `$_self` — the
pattern failing is how tier 3 declines instead of inventing a path. A file
sourced by a *relative* path (`. lib/resolve-target.sh`) also fails that
pattern, and declining is the right answer there too: the cwd it would have to
guess from is the caller's, not the plugin's.

zsh and bash reach tier 3. `dash` and `sh` have no self-path at all, so with
`CLAUDE_PLUGIN_ROOT` unset they stop at tier 5 — same as any pasted block, and
for the same reason: nothing left is knowable. Tier 3 is a bonus, never a
guarantee; the proof is what holds.

Both snippets on this page are asserted by
[`plugin-root.selfcheck.sh`](plugin-root.selfcheck.sh), which runs them across
every shell present and checks that tier 5 stops, names the path it tried, and
exports nothing; that a file which defines nothing fails the proof; and that
neither snippet resolves from the cwd even when the cwd genuinely is the
checkout. Run it before changing either snippet, and copy its tier-5 case into a
rollout PR's test plan.

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
- `"${VAR:-$PWD}/..."` — a non-empty default that the caller, or a PR under
  review, controls. It fixes the root-collapse bug and opens the one in
  `harness-skills#22`; see "There is no tier 4" above.
- `"$CLAUDE_PLUGIN_ROOT/..."` — no default at all
- `export`ing any path before the load has proved it

Allowed: a non-empty default nobody downstream can write
(`${VAR:-$HOME/dotfiles}`), or bind-then-guard
(`_root="${VAR:-}"; [ -n "$_root" ] || <tier 3/5>`).

One grep is the gate. It has no false positives — an empty default, or a `$PWD`
default, immediately followed by `/` is always the defect, and a guarded
`[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]` does not match it:

```sh
git ls-files -z | xargs -0 grep -nE '\$\{[A-Za-z_][A-Za-z0-9_]*:?-(\$PWD)?\}/' \
  | grep -v '^references/plugin-root\.md:' \
  || echo "ok  no empty-default or \$PWD path splices"
```

The one exclusion is this file, which quotes the banned patterns to show them. No
sibling repo needs it — they link here rather than copying, so the path does not
exist there and the filter is inert.

Driven off `git ls-files` rather than a `skills lib` path list, for the same
reason this repo's emoji check is: the carriers live in different directories in
different siblings, and a literal path list exits 2 on the repos that have no
`lib/` — a spurious failure that teaches people to ignore the gate.

A second grep is a review prompt, not a gate, because it cannot see the guard:

```sh
git ls-files -z | xargs -0 grep -nE '\$\{?CLAUDE_PLUGIN_ROOT\}?/'
```

Every hit must sit inside a guard that already ran — `[ -n "$VAR" ]` — and be
followed by the load proof before anything trusts it. Read them; do not "fix" a
guarded one.

The gate belongs in `.github/workflows/skill-check.yml` — the reusable workflow
this repo owns — but **only after the rollout lands**. Adding it today turns CI
red in the five siblings that still carry the defect, which is the wrong order
and is what `CLAUDE.md`'s "never add a check a sibling repo cannot pass" rule
forbids. Until then it runs per rollout PR, and this repo runs its own
self-check in `validate.yml`.

## Per-harness answers

| Harness | Sets a variable | Where the plugin lands | What a pasted block must do |
|---|---|---|---|
| Claude Code | `CLAUDE_PLUGIN_ROOT` | plugin cache | nothing — tier 2 hits |
| Codex | no | `~/.codex/plugins/` (`codex-tools.md`) | export `CLAUDE_PLUGIN_ROOT` first, else tier 5 |
| Gemini CLI | no | the extension dir it loaded `GEMINI.md` from | same |
| Antigravity | no | shares Gemini CLI's `~/.gemini` install (`antigravity-tools.md`) | same |
| Kimi CLI | no | the install dir named by `.kimi-plugin/plugin.json` | same |
| Hermes | no | `~/.hermes/plugins/<repo>/` (`hermes-tools.md`) | same |
| OpenCode | no | OpenCode's plugin manager dir | same |

No non-Claude harness exports an equivalent variable, and none is expected to.
That is the whole reason tier 5 exists rather than a sixth clever fallback.

## Not this question

Whether `.claude-plugin/plugin.json` exists at all (`authoring-skills#9`) is a
neighbouring problem, not this one: a manifest-less personal skill tree has no
plugin root to resolve. It gets the same tier-5 answer and is tracked separately.
