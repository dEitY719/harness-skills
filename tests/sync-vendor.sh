#!/usr/bin/env bash
# Exercises scripts/sync-shell-common-vendor.sh against a fixture SSOT and a
# fixture consumer. Offline: no network, no gh, no real dotfiles checkout.
set -euo pipefail

root=$(git rev-parse --show-toplevel)
sync=$root/scripts/sync-shell-common-vendor.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

dots=$work/dotfiles
ssot=$dots/shell-common/functions
vendor=$work/consumer/lib/vendor/shell-common/functions
mkdir -p "$ssot" "$dots/shell-common/tools" "$vendor" "$work/consumer/lib/vendor/shell-common/tools"
printf '#!/bin/sh\n# shell-common/functions/a.sh\nA=1\n' > "$ssot/a.sh"
printf 'B=2\n' > "$ssot/noshebang.sh"          # SSOT file with no shebang
printf 'C=3\n' > "$ssot/notvendored.sh"        # SSOT file this consumer skips
printf 'D=4\n' > "$ssot/helper.py"             # not a .sh
printf 'E=5\n' > "$dots/shell-common/tools/t.sh"   # outside functions/

# A copy is discovered by its own banner, not by living at a blessed path.
# The last two are the shapes a `functions/*.sh` glob skipped in silence.
stub() { printf '# SSOT: dEitY719/dotfiles %s\n' "$1" > "$2"; }
stub shell-common/functions/a.sh         "$vendor/a.sh"
stub shell-common/functions/noshebang.sh "$vendor/noshebang.sh"
stub shell-common/functions/helper.py    "$vendor/helper.py"
stub shell-common/tools/t.sh             "$work/consumer/lib/vendor/shell-common/tools/t.sh"
printf 'not vendored, no banner\n' > "$vendor/stray.sh"

fail=0
# The assertion runs INSIDE t, never as a bare command followed by `t $?`:
# under `set -e` a bare failing assertion kills the script before the helper
# can label it, which would report 20 assertions as a single bare `rc=1`.
t() {  # t <label> <command...>
    local label=$1; shift
    if "$@"; then echo "ok    $label"; else echo "FAIL  $label"; fail=1; fi
}
run() { "$sync" --ssot "$work/dotfiles" "$@" "$work/consumer"; }
rc_of() { local rc=0; "$@" >/dev/null 2>&1 || rc=$?; printf '%s' "$rc"; }
line() { sed -n "$1p" "$2"; }

out=$(run) && rc=0 || rc=$?
t "a sync of the banner-bearing files succeeds" [ "$rc" = 0 ]
t "it reports what it rewrote" grep -q 'sync  .*a\.sh' <<<"$out"

# The shebang stays on line 1 and the banner sits under it. Prepending the
# banner is what produced the SC1128 that turned five repos' main red (#11).
t "the shebang stays on line 1" [ "$(line 1 "$vendor/a.sh")" = '#!/bin/sh' ]
t "the banner starts on line 2" grep -q '^# VENDORED' <<<"$(line 2 "$vendor/a.sh")"
t "the banner names the SSOT path" \
  grep -qF 'SSOT: dEitY719/dotfiles shell-common/functions/a.sh' <<<"$(line 3 "$vendor/a.sh")"
t "the banner's third line is the stamp" \
  grep -q '^# Synced [0-9T:-]*Z by ' <<<"$(line 4 "$vendor/a.sh")"
t "the SSOT body follows verbatim, nothing dropped" \
  [ "$(sed -n '5,6p' "$vendor/a.sh")" = "$(tail -n +2 "$ssot/a.sh")" ]
t "an SSOT file with no shebang gets the banner first" \
  grep -q '^# VENDORED' <<<"$(line 1 "$vendor/noshebang.sh")"
t "an SSOT file the consumer does not vendor is never added" [ ! -e "$vendor/notvendored.sh" ]
t "a bannerless file in the vendor tree is left alone" \
  [ "$(cat "$vendor/stray.sh")" = 'not vendored, no banner' ]
t "a vendored copy that is not .sh is still synced" \
  grep -q '^D=4$' "$vendor/helper.py"
t "a vendored copy outside functions/ is still synced" \
  grep -q '^E=5$' "$work/consumer/lib/vendor/shell-common/tools/t.sh"
t "the banner names the generator's repo, so the path resolves from here" \
  grep -qF 'by dEitY719/harness-skills scripts/sync-shell-common-vendor.sh' "$vendor/a.sh"

t "--check is clean right after a sync" [ "$(rc_of run --check)" = 0 ]

printf 'TAMPERED\n' >> "$vendor/a.sh"
out=$(run --check 2>&1) && rc=0 || rc=$?
t "--check fails on a hand-edited copy" [ "$rc" = 1 ]
t "...naming the file that drifted" grep -q '^DRIFT .*a\.sh' <<<"$out"
t "--check writes nothing" [ "$(tail -n 1 "$vendor/a.sh")" = TAMPERED ]
run >/dev/null
t "a sync restores it" [ "$(tail -n 1 "$vendor/a.sh")" != TAMPERED ]

# Re-running must be a no-op even though the stamp is a timestamp: comparing it
# would make every copy read as drifted one minute after a sync.
before=$(cat "$vendor/a.sh")
t "--check stays clean across a stamp change" [ "$(rc_of run --check)" = 0 ]
t "a real re-sync succeeds" [ "$(rc_of run)" = 0 ]
t "and leaves the file byte-identical, stamp included" [ "$(cat "$vendor/a.sh")" = "$before" ]

rm "$ssot/a.sh"
t "a vendored file with no SSOT fails loudly" [ "$(rc_of run)" = 1 ]
t "a missing SSOT checkout fails loudly" \
  [ "$(rc_of "$sync" --ssot "$work/nowhere" "$work/consumer")" = 1 ]
t "naming no consumer repo is a usage error" \
  [ "$(rc_of "$sync" --ssot "$work/dotfiles")" = 2 ]
t "--help prints the usage line, so the header parser is not silently empty" \
  grep -qF 'sync-shell-common-vendor.sh [--check]' <<<"$("$sync" --help)"

[ "$fail" -eq 0 ] || exit 1
echo "ok    sync-shell-common-vendor behaves"
