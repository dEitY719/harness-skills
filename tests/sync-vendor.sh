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

# Stands in for the 1500-line integration file only one function of which is
# vendored. `_one_fn`'s body carries every shape a naive extractor gets wrong:
# a heredoc whose body has a `}` in column 1, a nested brace, a `<<-` heredoc
# with a QUOTED delimiter and a TAB-indented terminator, and -- the two that
# swallow the SSOT's whole tail rather than merely truncating -- a `<<` that is
# not a heredoc at all, once in prose and once as an arithmetic left shift.
one_fn() {
  cat <<'FN'
_one_fn() {
    cat <<EOF
}
EOF
    # prose may name a <<NOPE delimiter that never opens a heredoc
    m=$(( 1 << 3 ))
    cat <<-'QUOTED'
}
	QUOTED
    { echo 1; }
}
FN
}

# A MULTI-line function whose header line ends in `}`. An extractor that calls
# any first line ending in `}` a one-liner truncates this to that single line --
# and since both sides truncate identically it reports `ok`, so the drift
# asserted further down would never be seen.
multi_fn() {
  cat <<'FN'
_multi_fn() { p=${HOME}
    echo body
}
FN
}

# A header line whose trailing `}` is BACKSLASH-ESCAPED -- a literal brace being
# printed, not the syntax that closes the body. Counting it balances the `{` that
# opened the function and truncates the extraction to this single line.
esc_fn() {
  cat <<'FN'
_esc_fn() { printf '%s' \}
    echo body
}
FN
}
{ printf '# big.sh header\n_before() { echo b; }\n'; one_fn; multi_fn; esc_fn
  printf 'AFTER=1\n'; } > "$ssot/big.sh"

# `# Bridge only` opts a copy out only from its LEADING COMMENT BLOCK. This SSOT
# puts the marker in the body, behind a non-comment line, so the rendered copy
# must still be compared and regenerated. Widening the marker's blast radius to
# a whole-file grep -- the one judgement call in #27 -- freezes this file, which
# is exactly what the assertions on it below catch.
printf 'X=1\n# Bridge only. Body line, not a header opt-out.\nY=2\n' > "$ssot/marker_in_body.sh"

# A copy is discovered by its own banner, not by living at a blessed path.
# The last two are the shapes a `functions/*.sh` glob skipped in silence.
stub() { printf '# SSOT: dEitY719/dotfiles %s\n' "$1" > "$2"; }
stub shell-common/functions/a.sh         "$vendor/a.sh"
stub shell-common/functions/noshebang.sh "$vendor/noshebang.sh"
stub shell-common/functions/helper.py    "$vendor/helper.py"
stub shell-common/tools/t.sh             "$work/consumer/lib/vendor/shell-common/tools/t.sh"
stub shell-common/functions/marker_in_body.sh "$vendor/marker_in_body.sh"
printf 'not vendored, no banner\n' > "$vendor/stray.sh"

# Two banner shapes are deliberately NOT whole-file copies (#25): a partial
# extraction names its qualifier, a bridge stub says so in its header. Both
# carry the banner, so both were found -- and both were destroyed. #28 gives
# each a narrower check instead, so neither is merely announced any more.
{ printf '# SSOT: dEitY719/dotfiles shell-common/functions/big.sh\t(_one_fn)\n'
  printf '# Hand-written note that must survive a refresh.\n'
  one_fn; } > "$vendor/extracted.sh"
{ printf '# SSOT: dEitY719/dotfiles shell-common/functions/big.sh (_multi_fn)\n'
  multi_fn; } > "$vendor/extracted_multi.sh"
{ printf '# SSOT: dEitY719/dotfiles shell-common/functions/big.sh (_esc_fn)\n'
  esc_fn; } > "$vendor/extracted_esc.sh"
{ printf '# SSOT: dEitY719/dotfiles shell-common/functions/big.sh\n'
  printf '# Bridge only. Recovers a missing `_one_fn`; the rest of upstream\n'
  printf '# big.sh is not vendored.\n'
  printf '. ./extracted.sh\n'; } > "$vendor/bridge.sh"
# #30: scraped prose cannot carry a contract -- under the backtick rule this
# stub passes on `_multi_fn` alone, so losing `_one_fn` upstream is a false
# green even though the stub exists to recover it. `# Bridges:` states what the
# stub owes, and ALL of it must still be there.
{ printf '# SSOT: dEitY719/dotfiles shell-common/functions/big.sh\n'
  printf '# Bridge only. Recovers `_one_fn`; `_multi_fn` is read by the same\n'
  printf '# caller, and `_SC` below is prose, not a promise.\n'
  printf '# Bridges: _one_fn, _multi_fn\n'
  printf '. ./extracted.sh\n'; } > "$vendor/bridge_field.sh"
# The two shapes that state no checkable contract stay reported skips.
{ printf '# SSOT: dEitY719/dotfiles shell-common/functions/big.sh\n'
  printf '# Bridge only. Names no symbol at all.\n'
  printf 'Z=9\n'; } > "$vendor/bridge_bare.sh"
{ printf '# SSOT: dEitY719/dotfiles shell-common/functions/big.sh (lines 3-9)\n'
  printf 'Z=9\n'; } > "$vendor/ranged.sh"

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
no() { ! "$@"; }   # `t <label> ! cmd` cannot work: `!` is not a command
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

# #25/#28: a copy that is not a whole-file copy is never rewritten from the
# whole SSOT -- but it is not left unchecked either. Each shape is VERIFIED by
# a narrower rule, and only a shape that states no checkable contract is
# skipped. Silently omitting either would be the same class of defect as
# silently overwriting it.
t "a partial extraction is verified, not skipped" grep -q '^ok    .*extracted\.sh' <<<"$out"
t "...naming the function it extracts" \
  grep -qF '(_one_fn)' <<<"$(grep 'extracted\.sh' <<<"$out")"
t "a partial extraction keeps its hand-written body" \
  grep -q 'must survive a refresh' "$vendor/extracted.sh"
t "a stub carrying the opt-out marker is verified against a symbol it names" \
  grep -q '^ok    .*bridge\.sh' <<<"$out"
t "...naming that symbol" \
  grep -qF '_one_fn still defined' <<<"$(grep 'bridge\.sh --' <<<"$out")"
t "a stub keeps its hand-written body" \
  [ "$(tail -n 1 "$vendor/bridge.sh")" = '. ./extracted.sh' ]
t "a stub with a 'Bridges:' field is verified against every name it lists" \
  grep -q '^ok    .*bridge_field\.sh' <<<"$out"
t "...naming all of them, not just the first that resolved" \
  grep -qF 'all of _one_fn _multi_fn' <<<"$out"
t "...and ignoring backticked prose the field never promised" \
  no grep -qF '_SC' <<<"$(grep 'bridge_field\.sh' <<<"$out")"
t "a stub that names no symbol has no contract, so it stays a reported skip" \
  grep -q '^skip  .*bridge_bare\.sh' <<<"$out"
t "a qualifier that is not a function name stays a reported skip" \
  grep -q '^skip  .*ranged\.sh' <<<"$out"
t "a whole-file copy is still regenerated alongside them" grep -q '^A=1$' "$vendor/a.sh"
# The extraction's banner above separates path and qualifier with a TAB. awk's
# own `$4` split on any whitespace; a bash `%% *` split would read the tab as
# part of the path and chase an SSOT that does not exist (PR #27, codex).
t "a banner separated by a tab still resolves its SSOT path" \
  grep -qF 'matches shell-common/functions/big.sh' <<<"$(grep 'extracted\.sh' <<<"$out")"
t "the summary counts the skips rather than losing them" grep -q '2 skipped' <<<"$out"

t "--check is clean right after a sync" [ "$(rc_of run --check)" = 0 ]

cout=$(run --check) && crc=0 || crc=$?
t "--check exits 0 when the only non-matches are skips" [ "$crc" = 0 ]
t "--check reports the skips too, never silently omits them" \
  [ "$(grep -c '^skip  ' <<<"$cout")" = 2 ]
# The marker is scoped to the LEADING comment block. This copy now carries
# `# Bridge only` in its body, behind `X=1`; a whole-file grep would read that
# as an opt-out and report `skip`, freezing the file forever.
t "a 'Bridge only' line in the body is not a header opt-out" \
  grep -q '^ok    .*marker_in_body\.sh' <<<"$cout"
t "...so it is still a whole-file copy, body and all" \
  grep -q '^Y=2$' "$vendor/marker_in_body.sh"

# #28: an extraction that is only announced is frozen. Both copies run through
# the same extractor, so a truncating one truncates both and still calls them
# equal -- the change below lands AFTER the heredoc whose body has a column-1
# `}`, so only an extractor that stepped over it sees any difference at all.
sed -i 's/^    { echo 1; }$/    { echo 2; }/' "$ssot/big.sh"
out=$(run --check 2>&1) && rc=0 || rc=$?
t "drift past the extraction's heredoc turns --check red" [ "$rc" = 1 ]
t "...naming the extraction that drifted" grep -q '^DRIFT .*extracted\.sh' <<<"$out"
t "--check writes nothing to an extraction either" \
  grep -q '{ echo 1; }' "$vendor/extracted.sh"

run >/dev/null
t "write mode refreshes the extracted slice" grep -q '{ echo 2; }' "$vendor/extracted.sh"
t "...leaving the copy's own header alone" grep -q 'must survive a refresh' "$vendor/extracted.sh"
t "...and never dragging in the rest of the SSOT" \
  no grep -q '^AFTER=1$' "$vendor/extracted.sh"
t "a refreshed extraction is clean on the next check" [ "$(rc_of run --check)" = 0 ]

# The `one`-liner shortcut must not fire on `_multi_fn`, whose HEADER line ends
# in `}` but whose body runs on. If it does, only that first line is compared,
# both sides truncate to it identically, and this drift is reported `ok`.
sed -i 's/^    echo body$/    echo body2/' "$ssot/big.sh"
out=$(run --check 2>&1) && rc=0 || rc=$?
t "drift below a header line ending in '}' still turns --check red" [ "$rc" = 1 ]
t "...naming the multi-line extraction" grep -q '^DRIFT .*extracted_multi\.sh' <<<"$out"
run >/dev/null
t "write mode refreshes it without dragging in the SSOT tail" \
  no grep -q '^AFTER=1$' "$vendor/extracted_multi.sh"
sed -i 's/^    echo body2$/    echo body/' "$ssot/big.sh"
run >/dev/null
t "restoring it upstream restores a clean check" [ "$(rc_of run --check)" = 0 ]

# An escaped `\}` on the header line is a literal brace, not syntax. Counting it
# balances the opening `{`, fires the one-liner shortcut, and truncates -- again
# identically on both sides, so the drift below would be reported `ok`.
sed -i 's/^    echo body$/    echo body3/' "$ssot/big.sh"
out=$(run --check 2>&1) && rc=0 || rc=$?
t "drift below a header line ending in an escaped brace turns --check red" [ "$rc" = 1 ]
t "...naming the escaped-brace extraction" grep -q '^DRIFT .*extracted_esc\.sh' <<<"$out"
run >/dev/null
t "write mode refreshes it without dragging in the SSOT tail" \
  no grep -q '^AFTER=1$' "$vendor/extracted_esc.sh"
sed -i 's/^    echo body3$/    echo body/' "$ssot/big.sh"
run >/dev/null
t "restoring the escaped-brace function restores a clean check" [ "$(rc_of run --check)" = 0 ]

# The failure the whole issue is about: upstream renames or deletes the symbol.
sed -i 's/^_one_fn() {/_gone_fn() {/' "$ssot/big.sh"
out=$(run --check 2>&1) && rc=0 || rc=$?
t "a symbol that vanished upstream turns --check red" [ "$rc" = 1 ]
t "...failing the extraction, by name" \
  grep -q '_one_fn' <<<"$(grep '^FAIL  .*extracted\.sh' <<<"$out")"
t "...failing the bridge stub that promised it, by name" \
  grep -q '_one_fn' <<<"$(grep '^FAIL  .*bridge\.sh' <<<"$out")"
# The whole point of #30: `_multi_fn` is still a function of big.sh, so the
# at-least-one backtick rule reports this stub `ok` while the symbol it exists
# to recover is gone. The field turns that false green red, and names only the
# name that actually went missing.
t "a 'Bridges:' field fails when ONE of its names vanishes" \
  grep -q '^FAIL  .*bridge_field\.sh' <<<"$out"
t "...naming the symbol that went, not the one that survived" \
  [ "$(grep -o '_one_fn\|_multi_fn' <<<"$(grep 'bridge_field\.sh' <<<"$out")" | sort -u)" = _one_fn ]
t "write mode does not paper over a vanished symbol" [ "$(rc_of run)" = 1 ]
t "...and leaves the extraction's body untouched" grep -q '{ echo 2; }' "$vendor/extracted.sh"
sed -i 's/^_gone_fn() {/_one_fn() {/' "$ssot/big.sh"
t "restoring the symbol upstream restores a clean check" [ "$(rc_of run --check)" = 0 ]

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

# A field entry lands in a grep pattern. A non-identifier there is a broken
# field, not a quietly wider search that would match anything and pass. The
# second entry is the trap: split unquoted, `_glob*` PATHNAME-EXPANDS against
# the cwd, so `_globbed_fn` below would turn a broken field into a plausible
# name and the entry would never be reported at all. Hence the `cd`.
{ printf '# SSOT: dEitY719/dotfiles shell-common/functions/big.sh\n'
  printf '# Bridge only.\n'
  printf '# Bridges: _one.*, _glob*\n'
  printf 'Z=9\n'; } > "$vendor/bridge_badfield.sh"
: > "$work/_globbed_fn"
out=$(cd "$work" && run --check 2>&1) || true
t "a 'Bridges:' entry that is not a function name is a loud failure" \
  grep -q '^FAIL  .*bridge_badfield\.sh' <<<"$out"
t "...naming the bad entry rather than matching it as a pattern" \
  grep -qF '_one.*' <<<"$(grep 'bridge_badfield\.sh' <<<"$out")"
t "...and never pathname-expanding it against the cwd" \
  grep -qF '_glob*' <<<"$(grep 'bridge_badfield\.sh' <<<"$out")"
rm "$vendor/bridge_badfield.sh" "$work/_globbed_fn"

# #31: the SSOT checkout is read as a WORKING TREE, so its own freshness is
# part of the answer. Reproduces the exact shape that bit: `git fetch` had run,
# `git pull` had not, so origin/main was two commits ahead of a tree the script
# then called clean. `update-ref` stands in for that already-completed fetch --
# no network here, and none in the script either.
gdots=$work/gitdots
gcons=$work/gitconsumer
gvendor=$gcons/lib/vendor
mkdir -p "$gdots/shell-common/functions" "$gvendor"
# Quiet, and hook-free: the author's global core.hooksPath would otherwise
# print into the middle of the assertion log.
g() { git -C "$gdots" -c user.email=t@example.com -c user.name=t -c core.hooksPath=/dev/null "$@"; }
git init -q -b main "$gdots"
printf '#!/bin/sh\nV=1\n' > "$gdots/shell-common/functions/v.sh"
printf 'W=1\n' > "$gdots/shell-common/functions/other.sh"
g add -A && g commit -qm one >/dev/null
printf '#!/bin/sh\nV=2\n' > "$gdots/shell-common/functions/v.sh"
g add -A && g commit -qm two >/dev/null
# A remote with a fetch refspec, so `@{upstream}` really resolves: `branch.*.merge`
# alone leaves git unable to map refs/heads/main onto its remote-tracking ref.
g remote add origin "$gdots"
g update-ref refs/remotes/origin/main HEAD    # the fetch that already ran...
g config branch.main.remote origin
g config branch.main.merge refs/heads/main
g reset -q --hard HEAD~1                      # ...and the pull that did not
stub shell-common/functions/v.sh "$gvendor/v.sh"
grun() { "$sync" --ssot "$gdots" "$@" "$gcons"; }
behind_sha=$(g rev-parse HEAD)
ahead_sha=$(g rev-parse origin/main)

out=$(grun --check 2>&1) && rc=0 || rc=$?
t "a stale SSOT checkout turns --check red" [ "$rc" = 1 ]
t "...quoting the checked-out SHA" grep -qF "$behind_sha" <<<"$out"
t "...and the upstream SHA it is behind" grep -qF "$ahead_sha" <<<"$out"
t "...telling the operator to pull, not fetching itself" grep -qF 'pull --ff-only' <<<"$out"
t "...saying plainly that it made no network call" grep -qF 'no network call' <<<"$out"
t "write mode stops on a stale SSOT too" [ "$(rc_of grun)" = 1 ]
t "...before writing anything" [ "$(wc -l < "$gvendor/v.sh")" = 1 ]

out=$(grun --allow-stale-ssot 2>&1) && rc=0 || rc=$?
t "the escape hatch runs" [ "$rc" = 0 ]
t "...and announces itself" grep -q '^WARN.*--allow-stale-ssot' <<<"$out"
t "...vendoring the older revision it was pointed at" grep -q '^V=1$' "$gvendor/v.sh"

g merge -q --ff-only origin/main >/dev/null
out=$(grun --check 2>&1) && rc=0 || rc=$?
t "pulling exposes what the stale run vendored" [ "$rc" = 1 ]
t "...as ordinary drift" grep -q '^DRIFT .*v\.sh' <<<"$out"
grun >/dev/null
t "a level SSOT syncs the current revision" grep -q '^V=2$' "$gvendor/v.sh"
t "...and behaves exactly as before: clean is clean" [ "$(rc_of grun --check)" = 0 ]
t "...with no freshness complaint of any kind" \
  no grep -qE '^(WARN|note)' <<<"$(grun --check)"

# An uncommitted local edit would vendor out wearing an upstream banner, so it
# is worth a warning even when nothing vendored depends on it yet.
printf 'W=2\n' > "$gdots/shell-common/functions/other.sh"
out=$(grun --check 2>&1) && rc=0 || rc=$?
t "a dirty SSOT warns" grep -q '^WARN.*dirty' <<<"$out"
t "...naming the modified file" grep -q 'other\.sh' <<<"$out"
t "...without failing the run: it is a warning, not a gate" [ "$rc" = 0 ]
g checkout -q -- . >/dev/null

# A checkout with no upstream cannot be compared to anything. Say that, rather
# than crashing or -- worse -- reporting green.
g config --unset branch.main.remote
out=$(grun --check 2>&1) && rc=0 || rc=$?
t "a checkout with no upstream still runs" [ "$rc" = 0 ]
t "...and says what it could not check" grep -q '^note  .*no upstream' <<<"$out"

# The main fixture's SSOT is not a git checkout at all -- the same must hold.
t "a non-git SSOT says what it cannot check, rather than reporting green" \
  grep -q '^note  .*not a git checkout' <<<"$(run --check 2>&1 || true)"

[ "$fail" -eq 0 ] || exit 1
echo "ok    sync-shell-common-vendor behaves"
