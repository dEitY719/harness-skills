#!/usr/bin/env bash
# Exercises scripts/sync-shell-common-vendor.sh against a fixture SSOT and a
# fixture consumer. Offline: no network, no gh, no real dotfiles checkout.
set -euo pipefail

root=$(git rev-parse --show-toplevel)
sync=$root/scripts/sync-shell-common-vendor.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

ssot=$work/dotfiles/shell-common/functions
vendor=$work/consumer/lib/vendor/shell-common/functions
mkdir -p "$ssot" "$vendor"
printf '#!/bin/sh\n# shell-common/functions/a.sh\nA=1\n' > "$ssot/a.sh"
printf 'B=2\n' > "$ssot/noshebang.sh"          # SSOT file with no shebang
printf 'C=3\n' > "$ssot/notvendored.sh"        # SSOT file this consumer skips
: > "$vendor/a.sh"
: > "$vendor/noshebang.sh"

fail=0
check() {  # check <label> <condition-description> ; reads $? of the caller's test
    if [ "$1" = 0 ]; then echo "ok    $2"; else echo "FAIL  $2"; fail=1; fi
}
run() { "$sync" --ssot "$work/dotfiles" "$@" "$work/consumer"; }

out=$(run) && rc=0 || rc=$?
check "$rc" "a sync of two vendored files succeeds"
printf '%s' "$out" | grep -q 'sync  .*a\.sh' ; check $? "it reports what it rewrote"

# The shebang stays on line 1 and the banner sits under it. Prepending the
# banner is what produced the SC1128 that turned five repos' main red (#11).
[ "$(sed -n 1p "$vendor/a.sh")" = '#!/bin/sh' ]; check $? "the shebang stays on line 1"
sed -n 2p "$vendor/a.sh" | grep -q '^# VENDORED'; check $? "the banner starts on line 2"
sed -n 3p "$vendor/a.sh" | grep -qF 'SSOT: dEitY719/dotfiles shell-common/functions/a.sh'
check $? "the banner names the SSOT path"
sed -n 4p "$vendor/a.sh" | grep -q '^# Synced .* by scripts/sync-shell-common-vendor\.sh'
check $? "the banner names this script"
[ "$(sed -n 5,6p "$vendor/a.sh")" = "$(tail -n +2 "$ssot/a.sh")" ]
check $? "the SSOT body follows verbatim, nothing dropped"

sed -n 1p "$vendor/noshebang.sh" | grep -q '^# VENDORED'
check $? "an SSOT file with no shebang gets the banner first"

[ ! -e "$vendor/notvendored.sh" ]
check $? "an SSOT file the consumer does not vendor is never added"

run --check >/dev/null 2>&1; check $? "--check is clean right after a sync"

printf 'TAMPERED\n' >> "$vendor/a.sh"
out=$(run --check 2>&1) && rc=0 || rc=$?
[ "$rc" = 1 ]; check $? "--check fails on a hand-edited copy"
printf '%s' "$out" | grep -q '^DRIFT .*a\.sh'; check $? "...naming the file that drifted"
[ "$(tail -n 1 "$vendor/a.sh")" = TAMPERED ]; check $? "--check writes nothing"
run >/dev/null; [ "$(tail -n 1 "$vendor/a.sh")" != TAMPERED ]
check $? "a sync restores it"

# Re-running must be a no-op even though the stamp is a timestamp: comparing it
# would make every copy read as drifted one minute after a sync.
before=$(cat "$vendor/a.sh")
run --check >/dev/null; check $? "--check stays clean across a stamp change"
[ "$(cat "$vendor/a.sh")" = "$before" ]; check $? "and a re-sync leaves it byte-identical"

rm "$ssot/a.sh"
run >/dev/null 2>&1 && rc=0 || rc=$?
[ "$rc" = 1 ]; check $? "a vendored file with no SSOT fails loudly"

"$sync" --ssot "$work/nowhere" "$work/consumer" >/dev/null 2>&1 && rc=0 || rc=$?
[ "$rc" = 1 ]; check $? "a missing SSOT checkout fails loudly"

"$sync" --ssot "$work/dotfiles" >/dev/null 2>&1 && rc=0 || rc=$?
[ "$rc" = 2 ]; check $? "naming no consumer repo is a usage error"

[ "$fail" -eq 0 ] || exit 1
echo "ok    sync-shell-common-vendor behaves"
