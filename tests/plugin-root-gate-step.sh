#!/usr/bin/env bash
# Exercises the shared workflow's "No caller-controlled path defaults" step --
# the plugin-root tier-4 gate, hoisted out of the per-repo copies by
# harness-skills#59.
#
# The step is extracted from skill-check.yml rather than retyped, so what is
# tested is what ships, regex included. It also runs against THIS repo, whose
# references/plugin-root.md deliberately quotes every banned literal: the one
# case where the gate's own exclusion has to hold.
#
# Offline: no network, no gh, no package install.
set -euo pipefail

root=$(git rev-parse --show-toplevel)
work=$(mktemp -d)
fail=0
trap 'rm -rf "$work"' EXIT

# shellcheck source=tests/lib/step.sh
. "$root/tests/lib/step.sh"

step=$work/step.sh
extract "No caller-controlled path defaults" "$step"

# A real git repo: discovery is `git ls-files`, so an untracked scratch file
# must not be able to fail a caller's gate.
fixture=$work/repo
mkdir -p "$fixture/lib"
printf '#!/bin/sh\n_SC="${DOTFILES_ROOT:-$HOME/dotfiles}/shell-common"\n' > "$fixture/lib/ok.sh"
git -C "$fixture" init -q
git -C "$fixture" add -A
git -C "$fixture" -c user.email=t@t -c user.name=t commit -qm fixture

expect "a repo with only guarded defaults passes" "$fixture" 0 \
    "ok    no empty-default or cwd path splices"

# The four spellings the regex has to catch, one at a time so a failure names
# which one regressed. `.` and `$(pwd)` are the two a $PWD-only alternation
# passed (harness-skills#35), and `.` is the one that actually shipped in
# claudecode-skills#5.
commit_bad() {  # commit_bad <shell-line>
    printf '#!/bin/sh\n%s\n' "$1" > "$fixture/lib/bad.sh"
    git -C "$fixture" add -A
    git -C "$fixture" -c user.email=t@t -c user.name=t commit -qm bad
}

commit_bad '_SC="${CLAUDE_PLUGIN_ROOT:-}/lib/vendor/shell-common"'
expect "an empty default spliced into a path fails" "$fixture" 1 \
    'lib/bad.sh:2: _SC="${CLAUDE_PLUGIN_ROOT:-}/lib/vendor/shell-common"'

commit_bad '_SC="${CLAUDE_PLUGIN_ROOT-}/lib/vendor/shell-common"'
expect "the \${VAR-} form (no colon) fails too" "$fixture" 1 \
    "caller-controlled or empty path default"

commit_bad '_SC="${CLAUDE_PLUGIN_ROOT:-$PWD}/lib/vendor/shell-common"'
expect "a \$PWD default fails (retired tier 4)" "$fixture" 1 \
    "caller-controlled or empty path default"

commit_bad '_SC="${CLAUDE_PLUGIN_ROOT:-.}/lib/vendor/shell-common"'
expect "a . default fails -- the form claudecode-skills#5 shipped" "$fixture" 1 \
    "caller-controlled or empty path default"

commit_bad '_SC="${CLAUDE_PLUGIN_ROOT:-$(pwd)}/lib/vendor/shell-common"'
expect "a \$(pwd) default fails" "$fixture" 1 \
    "caller-controlled or empty path default"

# The failure has to be actionable: name the file and line, and say what to do
# instead. A gate that only says "no" gets ignored.
expect "the failure names the way out" "$fixture" 1 \
    "see references/plugin-root.md"

# No false positives, which is the claim the convention's page makes in so
# many words. A non-empty default nobody downstream can write is allowed, and
# so is a defaulted expansion that is not immediately followed by `/`.
rm -f "$fixture/lib/bad.sh"
cat > "$fixture/lib/allowed.sh" <<'ALLOWED'
#!/bin/sh
_SC="${DOTFILES_ROOT:-$HOME/dotfiles}/shell-common"
_root="${CLAUDE_PLUGIN_ROOT:-}"
[ -n "$_root" ] || exit 1
REMOTE="${REMOTE:-origin}"
printf '%s\n' "${GH_HOST:-github.com}"
ALLOWED
git -C "$fixture" add -A
git -C "$fixture" -c user.email=t@t -c user.name=t commit -qm allowed
expect "an allowed default, a bind-then-guard and a non-path default all pass" \
    "$fixture" 0 "ok    no empty-default or cwd path splices"

# A tracked symlink is skipped rather than followed: the target is checked on
# its own, and following it would report the same hit under two names.
ln -s allowed.sh "$fixture/lib/link.sh"
git -C "$fixture" add -A
git -C "$fixture" -c user.email=t@t -c user.name=t commit -qm link
expect "a tracked symlink does not double-report" "$fixture" 0 \
    "ok    no empty-default or cwd path splices"

# This repo is the exclusion's only real test: references/plugin-root.md has to
# quote every literal it bans, and every other tracked file has to be clean.
expect "this repo passes, with its own convention page excluded" "$root" 0 \
    "ok    no empty-default or cwd path splices"

# ...and the exclusion is exactly one file, not a blanket for references/.
cp "$root/references/plugin-root.md" "$fixture/lib/copied-convention.md"
git -C "$fixture" add -A
git -C "$fixture" -c user.email=t@t -c user.name=t commit -qm copy
expect "a repo that COPIES the convention page is caught, not excluded" "$fixture" 1 \
    "lib/copied-convention.md"

[ "$fail" -eq 0 ] || exit 1
echo "ok    plugin-root tier-4 gate behaves"
