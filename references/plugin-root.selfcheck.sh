#!/bin/sh
# references/plugin-root.selfcheck.sh — assert the three canonical snippets in
# plugin-root.md behave as that file claims. Same convention as
# gh-issue-skills' lib/resolve-target.selfcheck.sh: the check lives beside the
# thing it checks.
#
#   sh references/plugin-root.selfcheck.sh
#
# Exits 0 with "ok" lines, or non-zero naming the first failed assertion.

set -eu

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT INT TERM

mkdir -p "$WORK/plugin/lib/vendor/shell-common/functions" "$WORK/elsewhere" "$WORK/nohome" "$WORK/emptyroot"
# A real shell-common defines the function the proof looks for. An empty file
# would satisfy an [ -f ] check and fail the proof — which is the upgrade.
#
# It also does what every real vendored helper does at SOURCE time: resolve a
# sibling through ${SHELL_COMMON:-$HOME/dotfiles/shell-common} and warn when
# that misses. dEitY719/dotfiles' gh_host.sh and gh_pr_edit_safe.sh both reach
# for dotfiles_root.sh this way, and the warning is the observable that
# harness-skills#37 is about — so the fixture reproduces the lookup rather than
# just defining the function.
cat >"$WORK/plugin/lib/vendor/shell-common/functions/gh_host.sh" <<'HELPER'
_sib="${SHELL_COMMON:-$HOME/dotfiles/shell-common}/functions/dotfiles_root.sh"
if [ -f "$_sib" ]; then
    . "$_sib"
else
    printf '[gh_host] %s missing — #1454 guard skipped.\n' "$_sib" >&2
fi
_gh_resolve_host() { printf %s github.com; }
HELPER
printf '_dotfiles_root_guard_self() { :; }\n' \
    >"$WORK/plugin/lib/vendor/shell-common/functions/dotfiles_root.sh"

# The soft loader's helper. Separate from gh_host.sh on purpose: the soft form
# exists for a step that is optional, and a fixture that reused the host
# resolver would be asserting the soft shape over a helper no skill is allowed
# to lose.
cat >"$WORK/plugin/lib/vendor/shell-common/functions/gh_project_status.sh" <<'BOARD'
_sib="${SHELL_COMMON:-$HOME/dotfiles/shell-common}/functions/dotfiles_root.sh"
[ -f "$_sib" ] || printf '[gh_project_status] %s missing — guard skipped.\n' "$_sib" >&2
_gh_project_status_sync() { printf %s synced; }
BOARD

# A board tree that exists and defines nothing — the soft form's equivalent of
# $WORK/hollow, and what isolates the proof from the load. Without it, every
# "imposter" case below would be satisfied by the load simply missing, and
# would pass just as well against the exit-status proof it is meant to reject.
mkdir -p "$WORK/hollowboard/lib/vendor/shell-common/functions"
: >"$WORK/hollowboard/lib/vendor/shell-common/functions/gh_project_status.sh"

# A tree an earlier HARD block would have proved and exported — it defines the
# host resolver — but which ships no board helper. Assertion 12a needs exactly
# this: pointing SHELL_COMMON at a complete tree would let the soft block load
# from tier 1 and succeed, so the restore arm would never run and the assertion
# would pass without testing anything.
mkdir -p "$WORK/proven/functions"
printf '_gh_resolve_host() { printf %%s github.com; }\n' \
    >"$WORK/proven/functions/gh_host.sh"

# --- the pasted-block snippet, byte-verbatim from plugin-root.md -------------
# (only the trailing `printf 'RESOLVED=...'` probe is added, so the assertions
#  below can read what it resolved. Keep the rest identical: a fixture that
#  drifts from the doc tests the wrong thing.)
cat >"$WORK/block.sh" <<'BLOCK'
_SC="${DOTFILES_ROOT:-$HOME/dotfiles}/shell-common"
if [ ! -f "$_SC/functions/gh_host.sh" ]; then
    [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || {
        printf '[gh-pr:merge] no shell-common under %s, and CLAUDE_PLUGIN_ROOT is unset. On Claude Code this is a broken install; on any other harness export CLAUDE_PLUGIN_ROOT=<plugin dir> first.\n' \
            "$_SC" >&2
        return 1 2>/dev/null || exit 1
    }
    _SC="$CLAUDE_PLUGIN_ROOT/lib/vendor/shell-common"
fi
unset -f _gh_resolve_host 2>/dev/null || :
unalias _gh_resolve_host 2>/dev/null || :
export SHELL_COMMON="$_SC"
[ -f "$_SC/functions/gh_host.sh" ] && . "$_SC/functions/gh_host.sh"
[ "$(command -v _gh_resolve_host 2>/dev/null)" = _gh_resolve_host ] || {
    unset SHELL_COMMON
    printf '[gh-pr:merge] %s did not load a usable shell-common. On Claude Code this is a broken install; on any other harness export CLAUDE_PLUGIN_ROOT=<plugin dir> first.\n' \
        "$_SC" >&2
    return 1 2>/dev/null || exit 1
}
printf 'RESOLVED=%s\n' "$SHELL_COMMON"
BLOCK

# --- the self-locating snippet, verbatim from plugin-root.md -----------------
# (a ROOT= probe is added after tier selection, and the *final* tier-5 arm is
#  replaced by a PROVEN= probe so assertions 5 and 6 can see whether the proof
#  held rather than only that the script died. The tier-5 arm inside the `case`
#  stays verbatim — assertion 6 is precisely about it firing.)
cat >"$WORK/plugin/lib/resolve-target.sh" <<'SELF'
if [ -n "${ZSH_VERSION-}" ]; then
    _self="$0"
elif [ -n "${BASH_VERSION-}" ]; then
    # shellcheck disable=SC3028
    _self="${BASH_SOURCE[0]-}"
else
    _self=""
fi

_root="${CLAUDE_PLUGIN_ROOT:-}"
if [ -z "$_root" ]; then
    case "$_self" in
        */lib/resolve-target.sh) _root="${_self%/lib/resolve-target.sh}" ;;
        *)
            printf '[resolve-target] no plugin root: CLAUDE_PLUGIN_ROOT is unset and this shell gives the file no self-path. Export CLAUDE_PLUGIN_ROOT=<plugin dir> first.\n' >&2
            return 1 2>/dev/null || exit 1 ;;
    esac
fi
printf 'ROOT=%s\n' "$_root"
unset -f _gh_resolve_host 2>/dev/null || :
unalias _gh_resolve_host 2>/dev/null || :
export SHELL_COMMON="$_root/lib/vendor/shell-common"
[ -f "$SHELL_COMMON/functions/gh_host.sh" ] && . "$SHELL_COMMON/functions/gh_host.sh"
if [ "$(command -v _gh_resolve_host 2>/dev/null)" = _gh_resolve_host ]; then
    printf 'PROVEN=yes\n'
else
    printf 'PROVEN=no\n'
fi
SELF

# --- the soft warn-and-skip snippet, verbatim from plugin-root.md ------------
# (the real call inside the success arm is replaced by a SYNCED= probe — there
#  is no gh to call here — and a trailing LEFT= probe is added so the
#  restore-vs-unset assertions can read what the block handed back. The
#  resolution, the proof and the failure arm are byte-identical to the doc.)
cat >"$WORK/soft.sh" <<'SOFT'
_SC="${SHELL_COMMON:-$HOME/dotfiles/shell-common}"
if [ ! -f "$_SC/functions/gh_project_status.sh" ]; then
    [ -z "${CLAUDE_PLUGIN_ROOT:-}" ] ||
        _SC="$CLAUDE_PLUGIN_ROOT/lib/vendor/shell-common"
fi
_sc_was=${SHELL_COMMON+set} _sc_prev="${SHELL_COMMON-}"
unset -f _gh_project_status_sync 2>/dev/null || :
unalias _gh_project_status_sync 2>/dev/null || :
export SHELL_COMMON="$_SC"
[ -f "$_SC/functions/gh_project_status.sh" ] && . "$_SC/functions/gh_project_status.sh"
if [ "$(command -v _gh_project_status_sync 2>/dev/null)" = _gh_project_status_sync ]; then
    printf 'SYNCED=%s\n' "$(_gh_project_status_sync)"
else
    if [ -n "$_sc_was" ]; then export SHELL_COMMON="$_sc_prev"; else unset SHELL_COMMON; fi
    printf '[gh-pr:commit] no usable shell-common under %s — board sync skipped; the commit itself is unaffected.\n' \
        "$_SC" >&2
fi
unset _sc_was _sc_prev
printf 'LEFT=%s\n' "${SHELL_COMMON-UNSET}"
SOFT

# env -u for every variable that could mask a tier, so the machine running this
# does not decide the outcome.
clean() { env -u DOTFILES_ROOT -u SHELL_COMMON -u CLAUDE_PLUGIN_ROOT HOME="$WORK/nohome" "$@"; }

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

# Every "must refuse" assertion below is one shape: run a snippet with the
# environment cleaned, require a non-zero exit, and require the message to name
# the way out. `$out` is left set, so a caller needing a second claim about the
# text asserts it after the call rather than growing another copy of this.
refuses() {  # refuses <dir> <needle> <label> <cmd>...
    _dir=$1 _needle=$2 _label=$3
    shift 3
    if out=$(cd "$_dir" && clean "$@" 2>&1); then
        fail "$_label — it succeeded instead (got: $out)"
    fi
    case "$out" in
        *"$_needle"*) ;;
        *) fail "$_label — the refusal came from the wrong gate (got: $out)" ;;
    esac
}

# --- the shell matrix, discovered once ---------------------------------------
# Deduplicate by resolved binary: on Debian-family boxes /bin/sh IS dash, and
# running it twice under two names would report coverage that is not there.
#
# Classify by what each shell IS, never by the name it was invoked under. A name
# list silently encodes "/bin/sh is not bash", which some minimal images break:
# bash exports $BASH_VERSION even as `sh`, so it reaches tier 3, and a name list
# would assert the tier-5 refusal against it and fail. Asking the shell the same
# question the snippet asks is the only sound classifier — and combined with the
# dedup it also keeps the matrix from reporting four shells' coverage when four
# names resolve to one binary, which is why the names actually run are printed
# in the summary rather than kept private.
has_selfpath() {  # has_selfpath <shell> — the snippet's own branch condition
    [ "$("$1" -c 'if [ -n "${ZSH_VERSION-}" ] || [ -n "${BASH_VERSION-}" ]
                  then printf yes; else printf no; fi')" = yes ]
}

SHELLS="" seen="" noself=""
for shell in sh dash bash zsh; do
    path=$(command -v "$shell" 2>/dev/null) || continue
    real=$(readlink -f "$path" 2>/dev/null || echo "$path")
    case " $seen " in *" $real "*) continue ;; esac
    seen="$seen $real" SHELLS="$SHELLS $shell"
    has_selfpath "$shell" || { [ -n "$noself" ] || noself="$shell"; }
done

# 1. tier 2 — the variable is set, cwd is irrelevant.
got=$(cd "$WORK/elsewhere" && clean CLAUDE_PLUGIN_ROOT="$WORK/plugin" sh "$WORK/block.sh")
[ "$got" = "RESOLVED=$WORK/plugin/lib/vendor/shell-common" ] \
    || fail "tier 2 did not resolve from CLAUDE_PLUGIN_ROOT (got: $got)"

# 1b. the proof, not an existence check. A hollow gh_host.sh satisfies [ -f ]
#     and defines nothing; the block must still refuse. Same for a directory at
#     that path, which is the other case `unset -f` + `command -v` closes.
mkdir -p "$WORK/hollow/lib/vendor/shell-common/functions"
: >"$WORK/hollow/lib/vendor/shell-common/functions/gh_host.sh"
refuses "$WORK/elsewhere" "did not load a usable shell-common" \
    "a hollow gh_host.sh must fail the proof, not pass an existence check" \
    CLAUDE_PLUGIN_ROOT="$WORK/hollow" sh "$WORK/block.sh"

# 1c. the proof must test for a FUNCTION, not for a runnable name
#     (harness-skills#36). `command -v name >/dev/null` — the shape this
#     replaced — answers "is this name runnable", so with the hollow helper
#     above it passes whenever something else in scope owns the name: a PATH
#     executable in all four shells, an alias in three. Both are asserted per
#     shell because the shells disagree about the alias, and a one-shell check
#     would have called the old form fixed after testing only bash.
mkdir -p "$WORK/bin"
printf '#!/bin/sh\nprintf hijacked\n' >"$WORK/bin/_gh_resolve_host"
chmod +x "$WORK/bin/_gh_resolve_host"
printf '#!/bin/sh\nprintf hijacked\n' >"$WORK/bin/_gh_project_status_sync"
chmod +x "$WORK/bin/_gh_project_status_sync"
for shell in $SHELLS; do
    refuses "$WORK/elsewhere" "did not load a usable shell-common" \
        "$shell: a PATH executable named _gh_resolve_host must not pass the proof" \
        PATH="$WORK/bin:$PATH" CLAUDE_PLUGIN_ROOT="$WORK/hollow" "$shell" "$WORK/block.sh"

    refuses "$WORK/elsewhere" "did not load a usable shell-common" \
        "$shell: an alias named _gh_resolve_host must not pass the proof" \
        CLAUDE_PLUGIN_ROOT="$WORK/hollow" "$shell" -c \
        "alias _gh_resolve_host=true; . $WORK/block.sh"

    # ...and the `unalias` that closes the alias case must not cost a real
    # load: with an alias in scope AND a helper that genuinely defines the
    # function, the block still has to resolve. Without the `unalias`, sh,
    # dash and zsh all let the alias outrank the function (zsh never even
    # defines it), turning a good load into a false tier 5.
    # `|| true` so `set -e` cannot kill the script on the failing path before
    # fail() names which assertion broke — same reason assertion 4 has it.
    got=$(cd "$WORK/elsewhere" && clean CLAUDE_PLUGIN_ROOT="$WORK/plugin" "$shell" -c \
        "alias _gh_resolve_host=true; . $WORK/block.sh" 2>/dev/null) || true
    [ "$got" = "RESOLVED=$WORK/plugin/lib/vendor/shell-common" ] \
        || fail "$shell: a stale alias must not block a genuine load (got: $got)"
done

# 1c-bis. ...and an inherited FUNCTION must not pass either — the case `unset -f`
#     exists for, and the one the fixtures above could not see: they each run in
#     a fresh shell where no such function exists, so dropping `unset -f` changed
#     nothing and every assertion stayed green. A block sourced into a shell that
#     already defines the name is the normal case in these skills, where several
#     blocks run in sequence, and there an inherited definition certifies a tree
#     that loaded nothing.
for shell in $SHELLS; do
    refuses "$WORK/elsewhere" "did not load a usable shell-common" \
        "$shell: a function inherited from the caller must not pass the proof" \
        CLAUDE_PLUGIN_ROOT="$WORK/hollow" "$shell" -c \
        "_gh_resolve_host() { printf %s stale; }; . $WORK/block.sh"
done

# 1d. SHELL_COMMON must already be set while the helper is SOURCED
#     (harness-skills#37). Every vendored helper resolves its siblings through
#     ${SHELL_COMMON:-$HOME/dotfiles/shell-common} at source time, so exporting
#     after the proof is too late: on the tier-2 path the helper looked under a
#     $HOME/dotfiles that a plugin-only install does not have and skipped its
#     guard, quietly, once per helper. The observable is the helper's own
#     warning on stderr — the block resolves either way, which is why this went
#     unnoticed, and why asserting the exit status alone would not catch it.
err=$(cd "$WORK/elsewhere" && clean CLAUDE_PLUGIN_ROOT="$WORK/plugin" \
    sh "$WORK/block.sh" 2>&1 >/dev/null) || true
[ -z "$err" ] \
    || fail "the helper could not find its sibling while sourcing — SHELL_COMMON was set too late (got: $err)"

# 2. the retired tier 4 — the cwd genuinely IS the checkout, and the block must
#    STILL refuse. This is the case that used to succeed by guessing $PWD, and
#    the reason harness-skills#22 dropped it: a hostile PR is also "the cwd".
refuses "$WORK/plugin" "CLAUDE_PLUGIN_ROOT is unset" \
    "the pasted block must refuse \$PWD even in the real checkout (tier 4 is back)" \
    sh "$WORK/block.sh"

# 3. tier 5 — no variable, cwd is not the checkout. This is the case that used
#    to yield /lib/vendor/shell-common. It must fail, loudly, naming the path it
#    tried — which is tier 1's, since tier 2 was never reached.
refuses "$WORK/elsewhere" "$WORK/nohome/dotfiles/shell-common" \
    "tier 5 must stop and name the path it tried" \
    sh "$WORK/block.sh"
case "$out" in
    */lib/vendor/shell-common*) fail "a lib/vendor path was composed before the guard" ;;
    *) ;;
esac

# 4. the failure must not export a poisoned SHELL_COMMON. Both tier-5 arms get
#    their own case, because they now fail in different ways: the first bails
#    before SHELL_COMMON is ever set, while the second bails AFTER the block set
#    it for the helpers to read (harness-skills#37) and has to take it back. One
#    assertion covering only the first arm would have called the `unset` covered
#    while never running it.
got=$(cd "$WORK/elsewhere" && clean sh -c \
    ". $WORK/block.sh; printf 'leaked=%s\n' \"\${SHELL_COMMON-UNSET}\"" 2>/dev/null || true)
case "$got" in
    *leaked=UNSET*) ;;
    *) fail "SHELL_COMMON was exported despite the tier-5 bail (got: $got)" ;;
esac

# 4b. the proof-failure arm: tier 2 resolved, the block exported SHELL_COMMON so
#     the helper could read it, and then the load did not prove out. The `unset`
#     in that arm is what keeps a tree that failed to load from outranking every
#     later ${SHELL_COMMON:-...} default — gh-resolve-skills#8's poisoning,
#     reached by the other road.
got=$(cd "$WORK/elsewhere" && clean CLAUDE_PLUGIN_ROOT="$WORK/hollow" sh -c \
    ". $WORK/block.sh; printf 'leaked=%s\n' \"\${SHELL_COMMON-UNSET}\"" 2>/dev/null || true)
case "$got" in
    *leaked=UNSET*) ;;
    *) fail "SHELL_COMMON survived a failed proof (got: $got)" ;;
esac

# 5. tier 2 beats everything, in one shell — the branch it takes is plain POSIX
#    parameter expansion, identical everywhere, so running it per shell would
#    assert nothing extra.
got=$(cd "$WORK/elsewhere" && clean CLAUDE_PLUGIN_ROOT=/OVERRIDE sh -c \
    ". $WORK/plugin/lib/resolve-target.sh" | head -1)
[ "$got" = "ROOT=/OVERRIDE" ] || fail "tier 2 did not win over the self-path (got: $got)"

# 6. the self-path branch, asserting what plugin-root.md actually claims: a
#    shell that sets $ZSH_VERSION or $BASH_VERSION reaches tier 3 and proves
#    out; one that sets neither has no self-path and must stop at tier 5.
#    Accepting "either one" would let the doc's per-shell claim rot unnoticed.
for shell in $SHELLS; do
    if has_selfpath "$shell"; then
        out=$(cd "$WORK/elsewhere" && clean "$shell" -c ". $WORK/plugin/lib/resolve-target.sh")
        got=$(echo "$out" | head -1)
        [ "$got" = "ROOT=$WORK/plugin" ] \
            || fail "$shell sets \$BASH_VERSION/\$ZSH_VERSION so it must reach tier 3 (self-path), but gave: $got"
        # Tier 3 found the real checkout, so the load must define the
        # function. That is the proof, and it is what tier 3 buys.
        echo "$out" | grep -q '^PROVEN=yes$' \
            || fail "$shell reached tier 3 but the proof did not say PROVEN=yes"
    else
        refuses "$WORK/elsewhere" "CLAUDE_PLUGIN_ROOT is unset" \
            "$shell has no self-path and must stop at tier 5" \
            "$shell" -c ". $WORK/plugin/lib/resolve-target.sh"
    fi
done

# 7. and no self-path must still stop at tier 5 once the cwd IS the checkout —
#    the self-locating file's half of assertion 2. There is nothing left that
#    would let the cwd stand in for a root. Run it under a shell the loop above
#    proved has none, not a bare `sh`: where /bin/sh is bash, `sh` reaches tier
#    3 and this would be asserting the opposite claim. If every shell here has a
#    self-path there is nothing to assert, and saying so beats a false "ok".
if [ -n "$noself" ]; then
    refuses "$WORK/plugin" "CLAUDE_PLUGIN_ROOT is unset" \
        "no self-path must refuse even in the real checkout" \
        "$noself" -c ". $WORK/plugin/lib/resolve-target.sh"
    noself_note="ok  no self-path refuses even in the real checkout ($noself)"
else
    noself_note="skip  every shell here has a self-path; the no-self-path-in-checkout case did not run"
fi

# 8. `set -e` must not swallow the missing-shell-common case — the load-bearing
#    bullet above claims the `[ -f ] && .` shape keeps a missing file from
#    aborting a `set -e` caller before the tier-5 diagnostic runs. Assert that
#    for real instead of taking the bullet's word for it: point tier 2 at a
#    directory with no `lib/vendor/shell-common` at all (genuinely missing,
#    not the hollow-but-present fixture assertion 1b already covers), source
#    from a shell that has `set -e` on, and require the diagnostic to still
#    print (a silent early exit would leave `$out` empty, and `refuses()`'s
#    needle check already fails closed on that). The self-locating form's
#    final checkpoint is the identical `unset -f` / `.` / `command -v` idiom —
#    its fixture above replaces that checkpoint with a `PROVEN=` probe for
#    assertions 5-7, so it cannot itself raise the failure this checks for;
#    one exercise of the shared idiom is the evidence for both call sites.
refuses "$WORK/elsewhere" "did not load a usable shell-common" \
    "set -e must not swallow a missing shell-common" \
    sh -c "set -e; CLAUDE_PLUGIN_ROOT=$WORK/emptyroot; export CLAUDE_PLUGIN_ROOT; . $WORK/block.sh"

# --- the soft warn-and-skip form (harness-skills#60) -------------------------
# Same proof, same export ordering, a different failure arm. Each assertion
# below is about the part that DIFFERS; the shared parts are exercised by 1b-1d
# above over the same idiom.
#
# 9. It resolves and runs, from tier 2, exactly like the hard form.
got=$(cd "$WORK/elsewhere" && clean CLAUDE_PLUGIN_ROOT="$WORK/plugin" sh "$WORK/soft.sh")
case "$got" in
    *SYNCED=synced*) ;;
    *) fail "the soft loader did not resolve and run from tier 2 (got: $got)" ;;
esac

# 10. It WARNS and CONTINUES rather than stopping — exit 0, the optional step
#     skipped, and the warning naming the path it tried. A soft block that
#     exits non-zero is a hard block with a friendly message, and a soft block
#     that says nothing is the silent skip the doc's condition 4 forbids: both
#     are asserted, because each alone passes for the other's bug.
if ! out=$(cd "$WORK/elsewhere" && clean CLAUDE_PLUGIN_ROOT="$WORK/emptyroot" \
    sh "$WORK/soft.sh" 2>&1); then
    fail "the soft loader stopped the run instead of skipping the step (got: $out)"
fi
case "$out" in
    *"board sync skipped"*) ;;
    *) fail "the soft loader skipped silently — no warning (got: $out)" ;;
esac
case "$out" in
    *"$WORK/emptyroot/lib/vendor/shell-common"*) ;;
    *) fail "the soft loader's warning does not name the path it tried (got: $out)" ;;
esac
case "$out" in
    *SYNCED=*) fail "the soft loader ran the step although the proof failed (got: $out)" ;;
    *) ;;
esac

# 11. The proof is the same proof, per shell. A false pass here is worse than
#     in the hard form: nothing stops, no warning prints, and the optional step
#     is reported done while an imposter answered for it.
#     $WORK/hollowboard, not $WORK/emptyroot: with the helper genuinely absent
#     the load fails on its own and every shape below "passes", including the
#     exit-status one. The hollow tree makes the proof the only thing deciding.
for shell in $SHELLS; do
    out=$(cd "$WORK/elsewhere" && clean PATH="$WORK/bin:$PATH" \
        CLAUDE_PLUGIN_ROOT="$WORK/hollowboard" "$shell" "$WORK/soft.sh" 2>&1) || true
    case "$out" in
        *"board sync skipped"*) ;;
        *) fail "$shell: a PATH executable owning the name passed the soft proof (got: $out)" ;;
    esac
    out=$(cd "$WORK/elsewhere" && clean CLAUDE_PLUGIN_ROOT="$WORK/hollowboard" "$shell" -c \
        "alias _gh_project_status_sync=true; . $WORK/soft.sh" 2>&1) || true
    case "$out" in
        *"board sync skipped"*) ;;
        *) fail "$shell: an alias owning the name passed the soft proof (got: $out)" ;;
    esac
    out=$(cd "$WORK/elsewhere" && clean CLAUDE_PLUGIN_ROOT="$WORK/hollowboard" "$shell" -c \
        "_gh_project_status_sync() { printf %s stale; }; . $WORK/soft.sh" 2>&1) || true
    case "$out" in
        *"board sync skipped"*) ;;
        *) fail "$shell: a function inherited from the caller passed the soft proof (got: $out)" ;;
    esac
    # ...and the `unalias` that closes the alias case must not cost a real load,
    # the same mirror assertion 1c makes for the hard form. This is the one that
    # fails when `unalias` is dropped, since the refusals above are satisfied by
    # any refusal at all.
    out=$(cd "$WORK/elsewhere" && clean CLAUDE_PLUGIN_ROOT="$WORK/plugin" "$shell" -c \
        "alias _gh_project_status_sync=true; . $WORK/soft.sh" 2>/dev/null) || true
    case "$out" in
        *SYNCED=synced*) ;;
        *) fail "$shell: a stale alias blocked a genuine soft load (got: $out)" ;;
    esac
done

# 11b. SHELL_COMMON must be set while the SOFT helper is sourced too — the same
#      harness-skills#37 observable as assertion 1d, asserted separately
#      because the soft block builds its own path and could regress alone. The
#      helper warns on stderr when its sibling lookup misses; a clean run and a
#      successful sync together are the evidence.
out=$(cd "$WORK/elsewhere" && clean CLAUDE_PLUGIN_ROOT="$WORK/plugin" \
    sh "$WORK/soft.sh" 2>&1 >/dev/null) || true
[ -z "$out" ] \
    || fail "the soft helper could not find its sibling while sourcing — SHELL_COMMON was set too late (got: $out)"

# 12. The failure arm RESTORES SHELL_COMMON; it does not unset it. This is the
#     one place the soft form deliberately departs from the hard one, and both
#     directions have to hold or the invariant "set iff a helper proved out"
#     breaks on one side:
#
#     12a. handed a proven value, the block must hand it straight back. A hard
#          block bound it in an earlier step and required code after this one
#          reads it, so clearing it here would let an OPTIONAL step's failure
#          take the run down — soft mode's blast radius, inverted.
got=$(cd "$WORK/elsewhere" && env -u DOTFILES_ROOT HOME="$WORK/nohome" \
    SHELL_COMMON="$WORK/proven" CLAUDE_PLUGIN_ROOT="$WORK/emptyroot" \
    sh "$WORK/soft.sh" 2>/dev/null) || true
case "$got" in
    *SYNCED=*) fail "12a did not reach the failure arm — the fixture tree answered the load (got: $got)" ;;
esac
case "$got" in
    *"LEFT=$WORK/proven"*) ;;
    *) fail "the soft failure arm destroyed an earlier block's proven SHELL_COMMON (got: $got)" ;;
esac

#     12b. handed nothing, it must leave nothing — the hard arm's `unset`, and
#          the half that keeps a tree which failed to load from being exported
#          (gh-resolve-skills#8).
got=$(cd "$WORK/elsewhere" && clean CLAUDE_PLUGIN_ROOT="$WORK/emptyroot" \
    sh "$WORK/soft.sh" 2>/dev/null) || true
case "$got" in
    *LEFT=UNSET*) ;;
    *) fail "the soft failure arm left the tree it just rejected exported (got: $got)" ;;
esac

#     12c. an EMPTY inherited SHELL_COMMON is restored as empty, not as unset.
#          `${VAR+set}` / `${VAR-}` distinguish the two; the `:` forms do not,
#          and a save written with them silently converts one to the other in
#          the exact case the save exists for.
got=$(cd "$WORK/elsewhere" && env -u DOTFILES_ROOT HOME="$WORK/nohome" \
    SHELL_COMMON= CLAUDE_PLUGIN_ROOT="$WORK/emptyroot" sh "$WORK/soft.sh" 2>/dev/null) || true
case "$got" in
    'LEFT=') ;;
    *) fail "an empty SHELL_COMMON was not restored as empty — the save used the \`:\` forms (got: $got)" ;;
esac

echo "ok  tier 2 resolves from CLAUDE_PLUGIN_ROOT"
echo "ok  a file that defines nothing fails the proof"
echo "ok  a PATH executable, alias or inherited function owning the name does not pass the proof"
echo "ok  a stale alias does not block a genuine load"
echo "ok  SHELL_COMMON is already set while the helper is sourced"
echo "ok  the pasted block refuses \$PWD even in the real checkout"
echo "ok  tier 5 stops loudly and names the path it tried"
echo "ok  a failed resolution exports nothing, from either tier-5 arm"
echo "ok  tier 2 wins over the self-path"
echo "ok  self-path shells reach tier 3 and prove out, the rest stop at tier 5 (covered:$SHELLS)"
echo "$noself_note"
echo "ok  set -e does not swallow a missing shell-common"
echo "ok  the soft loader resolves and runs from tier 2"
echo "ok  the soft loader warns and continues instead of stopping, naming the path"
echo "ok  a PATH executable, alias or inherited function does not pass the soft proof either, and a stale alias does not block a real one (covered:$SHELLS)"
echo "ok  SHELL_COMMON is already set while the soft helper is sourced"
echo "ok  the soft failure arm restores SHELL_COMMON, exports no failed tree, and keeps unset and empty apart"
