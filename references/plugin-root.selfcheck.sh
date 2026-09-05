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

# --- the pasted-block snippet, verbatim from plugin-root.md ------------------
cat >"$WORK/block.sh" <<'BLOCK'
_SC="${DOTFILES_ROOT:-$HOME/dotfiles}/shell-common"
[ -f "$_SC/functions/gh_host.sh" ] || _SC="${CLAUDE_PLUGIN_ROOT:-$PWD}/lib/vendor/shell-common"
[ -f "$_SC/functions/gh_host.sh" ] || {
    printf '[selfcheck] shell-common not found under %s.\n' "$_SC" >&2
    return 1 2>/dev/null || exit 1
}
export SHELL_COMMON="$_SC"
printf 'RESOLVED=%s\n' "$SHELL_COMMON"
BLOCK

# --- the self-locating-file snippet, verbatim from plugin-root.md ------------
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

# 5. the self-path branch: a shell with $BASH_SOURCE/$0 reaches tier 3, one
#    without it falls to tier 4 — and neither ever yields an empty root.
for shell in sh dash bash zsh; do
    command -v "$shell" >/dev/null 2>&1 || continue
    got=$(cd "$WORK/elsewhere" && clean "$shell" -c ". $WORK/plugin/lib/resolve-target.sh")
    case "$got" in
        "ROOT=$WORK/plugin")    ;;  # tier 3, self-path available
        "ROOT=$WORK/elsewhere") ;;  # tier 4, no self-path in this shell
        *) fail "$shell resolved an unexpected root: $got" ;;
    esac
    got=$(cd "$WORK/elsewhere" && clean CLAUDE_PLUGIN_ROOT=/OVERRIDE "$shell" -c \
        ". $WORK/plugin/lib/resolve-target.sh")
    [ "$got" = "ROOT=/OVERRIDE" ] || fail "$shell ignored tier 2 (got: $got)"
done

echo "ok  tier 2 resolves from CLAUDE_PLUGIN_ROOT"
echo "ok  tier 4 resolves from \$PWD in the checkout"
echo "ok  tier 5 stops loudly and names the resolved path"
echo "ok  a failed resolution exports nothing"
echo "ok  self-path branch lands on tier 3 or 4 in every available shell"
