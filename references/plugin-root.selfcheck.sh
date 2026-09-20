#!/bin/sh
# references/plugin-root.selfcheck.sh — assert the two canonical snippets in
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
printf '_gh_resolve_host() { printf %%s github.com; }\n' \
    >"$WORK/plugin/lib/vendor/shell-common/functions/gh_host.sh"

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
[ -f "$_SC/functions/gh_host.sh" ] && . "$_SC/functions/gh_host.sh"
[ "$(command -v _gh_resolve_host 2>/dev/null)" = _gh_resolve_host ] || {
    printf '[gh-pr:merge] %s did not load a usable shell-common. On Claude Code this is a broken install; on any other harness export CLAUDE_PLUGIN_ROOT=<plugin dir> first.\n' \
        "$_SC" >&2
    return 1 2>/dev/null || exit 1
}
export SHELL_COMMON="$_SC"
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
[ -f "$_root/lib/vendor/shell-common/functions/gh_host.sh" ] \
    && . "$_root/lib/vendor/shell-common/functions/gh_host.sh"
if [ "$(command -v _gh_resolve_host 2>/dev/null)" = _gh_resolve_host ]; then
    printf 'PROVEN=yes\n'
else
    printf 'PROVEN=no\n'
fi
SELF

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

# 4. the failure must not export a poisoned SHELL_COMMON.
got=$(cd "$WORK/elsewhere" && clean sh -c \
    ". $WORK/block.sh; printf 'leaked=%s\n' \"\${SHELL_COMMON-UNSET}\"" 2>/dev/null || true)
case "$got" in
    *leaked=UNSET*) ;;
    *) fail "SHELL_COMMON was exported despite the failure (got: $got)" ;;
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

echo "ok  tier 2 resolves from CLAUDE_PLUGIN_ROOT"
echo "ok  a file that defines nothing fails the proof"
echo "ok  a PATH executable or alias owning the name does not pass the proof"
echo "ok  a stale alias does not block a genuine load"
echo "ok  the pasted block refuses \$PWD even in the real checkout"
echo "ok  tier 5 stops loudly and names the path it tried"
echo "ok  a failed resolution exports nothing"
echo "ok  tier 2 wins over the self-path"
echo "ok  self-path shells reach tier 3 and prove out, the rest stop at tier 5 (covered:$SHELLS)"
echo "$noself_note"
echo "ok  set -e does not swallow a missing shell-common"
