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

## Hard or soft: pick the failure mode before the shape

Every snippet on this page below resolves a root and then loads a helper from
it. What differs is what happens when the load does not prove out, and that is
a property of the **skill's contract**, not of the loader:

- **Hard stop** — the skill's output is wrong or absent without this helper, so
  the run ends: `return 1 2>/dev/null || exit 1`. This is the default, and the
  two forms below are both hard.
- **Soft warn-and-skip** — the helper drives a step the skill already documents
  as optional, so the run continues with that step disabled and one warning.
  The form is at "Canonical form — soft warn-and-skip loader".

A loader may be soft only when **all four** hold. This is a test, not a
preference — the wrong answer here is how an optional-looking step turns out to
have been load-bearing:

1. the skill's own contract already says the step is optional (a board sync, a
   label nicety, a metrics comment) — not merely that it is cheap to lose;
2. the skill's primary artifact is correct and complete without it;
3. **nothing downstream reads what it loaded.** A loader that binds a value a
   later step consumes is not optional, however peripheral it looks — if it
   skips, the later step gets an unbound or stale value and that is a hard
   failure wearing a soft coat;
4. skipping is **observable**: one warning naming the path it tried. Silence
   makes "the helper was missing" indistinguishable from "there was nothing to
   do", and the second is the reading everyone defaults to.

Fail any one of them and the loader is hard. Target binding, argument parsing
and anything the report quotes are hard; there is no third option.

## Canonical form — pasted block

Hard stop. The shape every `github-target.md` site should converge on:

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
unalias _gh_resolve_host 2>/dev/null || :
export SHELL_COMMON="$_SC"                                                           # before the load
[ -f "$_SC/functions/gh_host.sh" ] && . "$_SC/functions/gh_host.sh"
[ "$(command -v _gh_resolve_host 2>/dev/null)" = _gh_resolve_host ] || {             # tier 5
    unset SHELL_COMMON
    printf '[gh-pr:merge] %s did not load a usable shell-common. On Claude Code this is a broken install; on any other harness export CLAUDE_PLUGIN_ROOT=<plugin dir> first.\n' \
        "$_SC" >&2
    return 1 2>/dev/null || exit 1
}
```

Seven things are load-bearing:

- **Tier 2 is never defaulted into a path.** `[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]`
  guards the assignment instead. That is what keeps tier 2 from collapsing to the
  filesystem root without reaching for a default like `:-$PWD` — see "There is no
  tier 4" above for why that default is not the way out.
- **The `unset -f` / `unalias` / `. ` / `command -v` proof**, converged on over
  three review rounds in `gh-issue-skills#14`. Clearing the name first means the
  test after the load proves *this* load, in *this* shell, defined the function
  — not one inherited from an earlier block, not a half-sourced file, not a
  directory sitting at that path. It says **nothing** about who put the file
  there: provenance is closed by there being no tier that guesses a root, not by
  this check. An existence test answers "is there a file" and no more, which is
  why it is no longer the last word.
- **The proof compares `command -v`'s output to the bare name; it does not just
  check its exit status** (`harness-skills#36`). `command -v` answers "is this
  name runnable", not "is this name a function": with the helper loading but
  defining nothing, a `PATH` executable called `_gh_resolve_host` passes the
  exit-status form in all four of `sh`, `dash`, `bash` and `zsh`, and an alias
  passes it in three. POSIX pins the output instead — a function or built-in
  prints the bare name, an external command its pathname, an alias a
  reinput-able `alias ...` string — so one `=` separates them with no
  non-POSIX `type -t` / `declare -F` / `typeset -f`, none of which `dash` has.
  `unalias` is the other half: without it a live alias outranks the function
  the load just defined in `sh`, `dash` and `zsh` (and in `zsh` stops it being
  defined at all), turning a good load into a false tier 5.
- The `[ -f ]` in front of the `.` is a **load guard, not the proof**. `.` is a
  special built-in, so a missing file aborts a `set -e` `dash`/`sh` outright and
  `|| :` does not catch it. `|| :` on the `unset -f` and the `unalias` is
  likewise for `zsh`, which returns non-zero when there was no function or alias
  to clear — the normal case.
- **`export SHELL_COMMON` sits before the load and is undone if the proof
  fails** (`harness-skills#37`). It used to sit after the proof, which reads
  safer and is wrong: every vendored helper resolves its own siblings through
  `${SHELL_COMMON:-$HOME/dotfiles/shell-common}` *at source time*, so on the
  tier-2 path it looked under a `$HOME/dotfiles` that a plugin-only install does
  not have, silently skipped `dotfiles_root.sh`'s `_dotfiles_root_guard_self`
  guard, and printed a warning per helper on every run. Setting it afterwards is
  too late for the only consumer that reads it. The observable contract is
  unchanged — after this block `SHELL_COMMON` is set if and only if a helper
  proved out — because the tier-5 arm `unset`s it again. That `unset` is not
  optional: leaving a tree that failed to load in `SHELL_COMMON` is the
  poisoned-export bug of `gh-resolve-skills#8`, and unsetting is what lets every
  later `${SHELL_COMMON:-...}` fall back to its own default instead.
- The skill name in the message is a literal, not a `$VAR` these blocks do not
  bind — an unbound name printing empty is the same class of bug.
- `return 1 2>/dev/null || exit 1`, not a bare `exit 1`. The same text gets
  pasted into a shell *and* sourced from a `references/*.sh.md`, and a bare
  `exit` in the sourced case kills the caller's shell. One form is correct in
  both, so there is only one form to copy.

## Canonical form — a `.sh` file that can locate itself

Hard stop. Prefer this: move the block into `lib/<name>.sh` and let the pasted block shrink
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
unalias _gh_resolve_host 2>/dev/null || :
export SHELL_COMMON="$_root/lib/vendor/shell-common"             # before the load
[ -f "$SHELL_COMMON/functions/gh_host.sh" ] && . "$SHELL_COMMON/functions/gh_host.sh"
[ "$(command -v _gh_resolve_host 2>/dev/null)" = _gh_resolve_host ] || {  # tier 5
    unset SHELL_COMMON
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

What decides the tier is whether the shell sets `$ZSH_VERSION` or
`$BASH_VERSION`, not the name it was invoked under. zsh and bash reach tier 3;
`dash`, and any other shell setting neither, has no self-path at all, so with
`CLAUDE_PLUGIN_ROOT` unset it stops at tier 5 — same as any pasted block, and
for the same reason: nothing left is knowable. `sh` belongs to whichever group
`/bin/sh` actually is: bash invoked as `sh` still exports `$BASH_VERSION` and
still reaches tier 3, which some minimal container images make the normal case.
Tier 3 is a bonus, never a guarantee; the proof is what holds.

All three snippets on this page are asserted by
[`plugin-root.selfcheck.sh`](plugin-root.selfcheck.sh), which runs them across
every shell present and checks that tier 5 stops, names the path it tried, and
exports nothing; that a file which defines nothing fails the proof, and neither
does a `PATH` executable or an alias that merely owns the name; that neither
hard snippet resolves from the cwd even when the cwd genuinely is the checkout;
and that the soft loader warns instead of stopping, still refuses an imposter,
and hands back the `SHELL_COMMON` it was given rather than clearing it. Run it
before changing any snippet, and copy its tier-5 case into a rollout PR's test
plan.

## Canonical form — soft warn-and-skip loader

For a step the four-part test above admits. `gh-pr-skills`' board-sync blocks
are the motivating set (`harness-skills#60`): projectV2 bookkeeping that must
never cost a commit, a PR or a merge.

```sh
_SC="${SHELL_COMMON:-$HOME/dotfiles/shell-common}"                                   # tier 1
if [ ! -f "$_SC/functions/gh_project_status.sh" ]; then
    [ -z "${CLAUDE_PLUGIN_ROOT:-}" ] ||                                              # tier 2
        _SC="$CLAUDE_PLUGIN_ROOT/lib/vendor/shell-common"
fi
_sc_was=${SHELL_COMMON+set} _sc_prev="${SHELL_COMMON-}"                              # save
unset -f _gh_project_status_sync 2>/dev/null || :
unalias _gh_project_status_sync 2>/dev/null || :
export SHELL_COMMON="$_SC"                                                           # before the load
[ -f "$_SC/functions/gh_project_status.sh" ] && . "$_SC/functions/gh_project_status.sh"
if [ "$(command -v _gh_project_status_sync 2>/dev/null)" = _gh_project_status_sync ]; then
    _gh_project_status_sync issue <N> "In progress" --only-from Backlog || :
else                                                                                 # tier 5, soft
    if [ -n "$_sc_was" ]; then export SHELL_COMMON="$_sc_prev"; else unset SHELL_COMMON; fi
    printf '[gh-pr:commit] no usable shell-common under %s — board sync skipped; the commit itself is unaffected.\n' \
        "$_SC" >&2
fi
unset _sc_was _sc_prev
```

Everything load-bearing in the hard form is load-bearing here **unchanged** —
`unset -f` + `unalias`, `export SHELL_COMMON` before the `.`, the `[ -f ]` load
guard, the output-comparing proof, the message naming the path. Read that list;
it is not restated. Four things differ, and only the first is a real design
decision:

- **The failure arm restores `SHELL_COMMON`; it does not unset it.** The hard
  form can unset unconditionally because it never returns to its caller. This
  one does, and in the consumers it is normally *not* the first loader in the
  run — the board-sync blocks open on `${SHELL_COMMON:-...}` precisely because
  a hard block bound it in an earlier step. Unsetting there would let an
  optional step's failure knock out the proven value every *required*
  `${SHELL_COMMON:-...}` after it reads, so a missing board helper would take
  the rest of the run down with it: the exact blast radius soft mode exists to
  avoid, inverted.

  The invariant is unchanged, not weakened. Across both forms it is
  **`SHELL_COMMON` is set if and only if a helper proved out** — and restoring
  is what keeps it true in both directions, because the value being restored is
  one that *did* prove out, in an earlier block. The hard arm's `unset` is the
  same rule in the case where there was nothing to restore. Leaving the
  *failed* tree exported is still `gh-resolve-skills#8` and still banned; this
  differs from that in which value survives, not in whether a bad one does.

  `${VAR+set}` and `${VAR-}`, not `${VAR:+...}` / `${VAR:-...}`: the `:` forms
  cannot tell unset from empty, and restoring an empty `SHELL_COMMON` as unset
  is a silent behaviour change in the one case the save exists to preserve.

- **One failure arm instead of two.** There is no early `[ -n
  "${CLAUDE_PLUGIN_ROOT:-}" ]` bail, because a soft block has nothing to bail
  *to* — an unset variable simply leaves `_SC` at tier 1, the load misses, and
  the single arm below handles it with the same message. The `[ -z ... ] ||`
  around the tier-2 assignment is still required, and for the ordinary reason:
  it is what keeps `$CLAUDE_PLUGIN_ROOT/...` from composing `/lib/vendor/...`
  out of an empty variable.

- **Tier 5 still means stop, and still names the path.** What stops is the
  optional step, not the run. Keeping the number is deliberate: there is no
  extra tier here, only a smaller thing being abandoned, and a block that
  degrades without saying which path it tried is not tier 5 at all — it is the
  silent skip condition 4 above forbids.

- **The call itself keeps its own `|| :`.** The proof says the function is
  loaded; it says nothing about the API call inside it succeeding. That is a
  second, unrelated soft failure and it needs its own suppression.

A soft block's proof is not the weaker case. A false pass in the hard form
stops the run, which is visible; here it calls whatever owns the name —
a `PATH` executable, an inherited function, an alias — prints no warning at
all, and reports the optional step as done.

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
- `"${VAR:-$PWD}/..."`, `"${VAR:-.}/..."`, `"${VAR:-$(pwd)}/..."` — three
  spellings of one non-empty default that the caller, or a PR under review,
  controls. They fix the root-collapse bug and open the one in
  `harness-skills#22`; see "There is no tier 4" above. `.` is the spelling
  `claudecode-skills#5` actually shipped, so the gate below must name all three.
- `"$CLAUDE_PLUGIN_ROOT/..."` — no default at all
- **leaving the failed path exported** once the load has not proved out.
  Setting `SHELL_COMMON` before the `.` is required, not banned — the helpers
  read it while they source (`harness-skills#37`). What poisons the run is not
  setting it early, it is *that tree* still being set after the proof said no.
  A hard block `unset`s it; a soft block restores whatever it was handed, which
  is the same rule wherever there was nothing to hand back.

Allowed: a non-empty default nobody downstream can write
(`${VAR:-$HOME/dotfiles}`), or bind-then-guard
(`_root="${VAR:-}"; [ -n "$_root" ] || <tier 3/5>`).

One grep is the gate, and **it runs in CI for every repo in the family** — as
the "No caller-controlled path defaults (plugin-root tier 4)" step of
[`.github/workflows/skill-check.yml`](../.github/workflows/skill-check.yml),
the reusable workflow this repo owns. It is a built-in with no input: a caller
that could switch it off is a caller that can ship the defect. You do not need
to copy it anywhere. To run the same check by hand:

```sh
git ls-files -z \
  | xargs -0 grep -nE '\$\{[A-Za-z_][A-Za-z0-9_]*:?-(\$PWD|\$\(pwd\)|\.)?\}/' \
  | grep -v '^references/plugin-root\.md:' \
  || echo "ok  no empty-default or cwd path splices"
```

It has no false positives — an empty default, or a default that names the cwd,
immediately followed by `/` is always the defect, and a guarded
`[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]` does not match it.

The alternation is the whole gate: a `$PWD`-only one passed `${VAR:-.}/` and
`${VAR:-$(pwd)}/`, which are the same caller-controlled path by another name —
and `:-.` is the form that slipped into `gh-issue-skills`' auto-labels prologue
(its PR #35) after that repo had already run this grep clean. Widening it costs
no false positives: an allowed default (`${VAR:-$HOME/dotfiles}/`) still names
something the caller cannot write, so it still does not match.

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

The move into `skill-check.yml` waited for the consumer rollout of
`harness-skills#35`/`#36`/`#37` to finish (`harness-skills#59`), because adding
it sooner would have turned CI red at once in every sibling still carrying the
defect — the wrong order, and what `CLAUDE.md`'s "never add a check a sibling
repo cannot pass" rule forbids. Now that every consumer is on the current form
the gate is shared, and `tests/plugin-root-gate-step.sh` exercises the shipped
step against a fixture for each of the four spellings. This repo additionally
runs `plugin-root.selfcheck.sh` from `validate.yml`, which is a different
check: the gate is about text nobody should write, the self-check is about the
snippets on this page behaving as it claims.

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
