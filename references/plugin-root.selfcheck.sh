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

mkdir -p "$WORK/plugin/lib/vendor/shell-common/functions" "$WORK/elsewhere" "$WORK/nohome"
: >"$WORK/plugin/lib/vendor/shell-common/functions/gh_host.sh"

# --- the pasted-block snippet, byte-verbatim from plugin-root.md -------------
# (only the trailing `printf 'RESOLVED=...'` probe is added, so the assertions
#  below can read what it resolved. Keep the rest identical: a fixture that
#  drifts from the doc tests the wrong thing.)
cat >"$WORK/block.sh" <<'BLOCK'
_SC="${DOTFILES_ROOT:-$HOME/dotfiles}/shell-common"
[ -f "$_SC/functions/gh_host.sh" ] || _SC="${CLAUDE_PLUGIN_ROOT:-$PWD}/lib/vendor/shell-common"
[ -f "$_SC/functions/gh_host.sh" ] || {
    printf '[gh-pr:merge] shell-common not found under %s. On Claude Code this is a broken install; on any other harness export CLAUDE_PLUGIN_ROOT=<plugin dir> first.\n' \
        "$_SC" >&2
    return 1 2>/dev/null || exit 1
}
export SHELL_COMMON="$_SC"
printf 'RESOLVED=%s\n' "$SHELL_COMMON"
BLOCK

# --- the self-locating snippet, verbatim from plugin-root.md -----------------
# (its tier-5 printf arm is replaced by a PROVEN= probe, so assertion 6 can see
#  whether the proof held rather than only that the script died.)
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
        *)                       _root="$PWD" ;;
    esac
fi
printf 'ROOT=%s\n' "$_root"
if [ -f "$_root/lib/vendor/shell-common/functions/gh_host.sh" ]; then
    printf 'PROVEN=yes\n'
else
    printf 'PROVEN=no\n'
fi
SELF

# env -u for every variable that could mask a tier, so the machine running this
# does not decide the outcome.
clean() { env -u DOTFILES_ROOT -u SHELL_COMMON -u CLAUDE_PLUGIN_ROOT HOME="$WORK/nohome" "$@"; }

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

# 1. tier 2 — the variable is set, cwd is irrelevant.
got=$(cd "$WORK/elsewhere" && clean CLAUDE_PLUGIN_ROOT="$WORK/plugin" sh "$WORK/block.sh")
[ "$got" = "RESOLVED=$WORK/plugin/lib/vendor/shell-common" ] \
    || fail "tier 2 did not resolve from CLAUDE_PLUGIN_ROOT (got: $got)"

# 2. tier 4 — no variable, but cwd genuinely is the checkout.
got=$(cd "$WORK/plugin" && clean sh "$WORK/block.sh")
[ "$got" = "RESOLVED=$WORK/plugin/lib/vendor/shell-common" ] \
    || fail "tier 4 did not resolve from \$PWD (got: $got)"

# 3. tier 5 — no variable, cwd is not the checkout. This is the case that used
#    to yield /lib/vendor/shell-common. It must fail, loudly, naming the path.
if err=$(cd "$WORK/elsewhere" && clean sh "$WORK/block.sh" 2>&1); then
    fail "tier 5 did not stop; it printed: $err"
fi
case "$err" in
    *"$WORK/elsewhere/lib/vendor/shell-common"*) ;;
    *) fail "tier 5 message does not name the resolved path (got: $err)" ;;
esac
case "$err" in
    /lib/vendor/*) fail "resolved to the filesystem root — the defect is back" ;;
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

# 6. the self-path branch, asserting what plugin-root.md actually claims:
#    bash and zsh reach tier 3, every other shell falls to tier 4. Accepting
#    "either one" would let the doc's per-shell claim rot unnoticed.
#
#    Deduplicate by resolved binary: on Debian-family boxes /bin/sh IS dash, and
#    running it twice under two names would report coverage that is not there.
seen=""
for shell in sh dash bash zsh; do
    path=$(command -v "$shell" 2>/dev/null) || continue
    real=$(readlink -f "$path" 2>/dev/null || echo "$path")
    case " $seen " in *" $real "*) continue ;; esac
    seen="$seen $real"

    out=$(cd "$WORK/elsewhere" && clean "$shell" -c ". $WORK/plugin/lib/resolve-target.sh")
    got=$(echo "$out" | head -1)
    case "$shell" in
        bash | zsh) want="ROOT=$WORK/plugin"    ; tier="3 (self-path)" ; proof=yes ;;
        *)          want="ROOT=$WORK/elsewhere" ; tier="4 (\$PWD)"     ; proof=no  ;;
    esac
    [ "$got" = "$want" ] || fail "$shell should reach tier $tier but gave: $got"

    # The proof is what separates the two: tier 3 found the real checkout, so it
    # holds; tier 4 guessed the cwd, so it must NOT — that is the guess getting
    # caught, and it is the whole reason the proof is in the snippet.
    echo "$out" | grep -q "^PROVEN=$proof\$" \
        || fail "$shell reached tier $tier but the proof did not say PROVEN=$proof"
done

# 7. and the same tier-4 guess, once the cwd IS the checkout, must prove out.
out=$(cd "$WORK/plugin" && clean sh -c ". $WORK/plugin/lib/resolve-target.sh")
echo "$out" | grep -q '^PROVEN=yes$' \
    || fail "tier 4 in the real checkout should prove out (got: $out)"

echo "ok  tier 2 resolves from CLAUDE_PLUGIN_ROOT"
echo "ok  tier 4 resolves from \$PWD in the checkout"
echo "ok  tier 5 stops loudly and names the resolved path"
echo "ok  a failed resolution exports nothing"
echo "ok  tier 2 wins over the self-path"
echo "ok  bash/zsh reach tier 3, other shells tier 4"
echo "ok  the proof accepts a real root and rejects a guessed one"
