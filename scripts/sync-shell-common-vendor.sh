#!/usr/bin/env bash
# Regenerate the vendored copies of dEitY719/dotfiles' shell-common files.
#
# The banner in all 24 vendored files already names this path. It named it
# before the script existed (harness-skills#14), so nothing kept a copy in sync
# with its SSOT and nothing detected drift. This is that tool.
#
# It lives here rather than in dotfiles because the five consumers (gh-flow-,
# gh-issue-, gh-pr-, gh-resolve- and gh-verify-skills) already depend on this
# repo for their shared CI workflow and references/, and on dotfiles for
# nothing. The SSOT checkout is an argument, so the script runs outside the
# author's $HOME.
#
# Discovery is by the banner, not by a path convention: each vendored file's
# own `# SSOT:` line says where it came from, so a copy under any subtree with
# any extension is found. A `lib/vendor/shell-common/functions/*.sh` glob would
# silently skip the `.py` and `shell-common/tools/` copies that already exist,
# and a sync tool that quietly does nothing is the bug this repo keeps fixing.
#
# The banner goes BELOW the shebang. Prepending it displaced the shebang to
# line 5, which is the SC1128 that turned five repos' main red (#11); a repo
# can narrow its shellcheck-exclude-paths back once its copies are regenerated.
#
# Usage:
#   scripts/sync-shell-common-vendor.sh [--check] [--ssot <dotfiles-checkout>] <repo>...
#
#   --check   report drift and write nothing; exit 1 if any copy is stale
#   --ssot    dotfiles checkout (default: ${DOTFILES:-$HOME/dotfiles})
#
# Only files that already carry the banner are refreshed. This never adds one:
# what a repo vendors is that repo's decision, not this script's.
#
# Two banner shapes mark a copy that is NOT a whole-file copy of its SSOT (#25),
# so rewriting it from the whole SSOT would be destruction rather than a sync.
# Each gets a narrower check of its own instead, because "skipped and reported"
# still leaves the copy frozen against an SSOT that moves under it (#28):
#
#   1. a QUALIFIER after the SSOT path -- a partial extraction:
#        # SSOT: dEitY719/dotfiles shell-common/tools/integrations/claude.sh (_dotfiles_setup_mode)
#      vendors one function out of a 1500-line file. Only that function is
#      compared, and write mode refreshes only that slice, so the copy's own
#      header and notes survive.
#   2. the OPT-OUT MARKER `# Bridge only` starting a line in the file's leading
#      comment block -- a hand-written stub whose body was never upstream's.
#      There is nothing to diff, so the assertion is that the bridge still has
#      something to bridge: at least one symbol its header names in backticks is
#      still a function of the SSOT.
#      Find them with: grep -rn '^# Bridge only' lib/vendor
set -euo pipefail

VENDOR_ROOT=lib/vendor
BANNER_SSOT='# SSOT: dEitY719/dotfiles '
BANNER_BY='dEitY719/harness-skills scripts/sync-shell-common-vendor.sh'
OPT_OUT='^# Bridge only'   # see the header: opt-out marker for a hand-written stub

# Reads the header above rather than restating it, so the two cannot drift.
usage() { sed -n '/^# Usage:/,/^set -/{ /^set -/d; s/^# \?//; p; }' "$0"; }

check_only=0
ssot=${DOTFILES:-$HOME/dotfiles}
repos=()

while [ $# -gt 0 ]; do
  case $1 in
    --check) check_only=1 ;;
    --ssot) shift; ssot=${1:?--ssot needs a path} ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "unknown flag: $1" >&2; usage >&2; exit 2 ;;
    *) repos+=("$1") ;;
  esac
  shift
done

if [ "${#repos[@]}" -eq 0 ]; then
  echo "FAIL  name at least one consumer repo" >&2
  usage >&2
  exit 2
fi

if [ ! -d "$ssot" ]; then
  echo "FAIL  no SSOT checkout at $ssot -- pass --ssot <dotfiles-checkout>" >&2
  exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
stamp=$(date -u +%Y-%m-%dT%H:%MZ)

render() {  # render <ssot-file> <ssot-relpath> -- the copy, banner under the shebang
  local src=$1 rel=$2 first rest=1
  IFS= read -r first < "$src" || true   # empty file: read fails, first stays empty
  case $first in
    '#!'*) printf '%s\n' "$first"; rest=2 ;;
  esac
  printf '# VENDORED — do not edit here.\n'
  printf '%s%s\n' "$BANNER_SSOT" "$rel"
  printf '# Synced %s by %s — re-run that script to update.\n' "$stamp" "$BANNER_BY"
  tail -n "+$rest" "$src"
}

# Only the timestamp is masked, not the whole line: the rest of it names the
# generator, and a copy still pointing at the old unqualified path IS stale.
strip_stamp() { sed 's|^\(# Synced \)[^ ]* \(by .*\)$|\1<stamp> \2|'; }

# Extract one shell function: `^<name>()` through its closing `^}`. A column-0
# `}` terminates rather than a brace counter, because in shell a nested brace is
# always indented while a counter miscounts `${x}`, `case` bodies and braces
# inside strings and comments. Heredoc bodies are stepped over so a `}` in one
# cannot end the function early. Empty output means the file does not define it.
extract_fn() {  # extract_fn <file> <name>
  awk -v n="$2" '
    !inf { if ($0 ~ "^" n "[ \t]*\\(\\)") { inf = 1; first = 1 } else next }
    hd != "" { print; if ($0 ~ "^[ \t]*" hd "$") hd = ""; next }
    {
      # Every test below reads the line with its comment removed and its
      # BACKSLASH-ESCAPED braces dropped. A `#` comment is not code, so it can
      # neither open a heredoc nor close the function -- `f() { # note }` is a
      # MULTI-line function. An escaped `\}` is a literal brace being printed,
      # not syntax, so it must not balance the `{` that opened the body.
      c = $0; sub(/(^|[ \t])#.*$/, "", c); gsub(/\\[{}]/, "", c)
      # `one` only when the header line both opens and closes the body. Testing
      # for a trailing `}` alone also fires on `f() { x=${BAR}` and truncates it.
      if (first) { one = (c ~ /\{/ && gsub(/\{/, "{", c) == gsub(/\}/, "}", c)); first = 0 }
      # A heredoc delimiter starts with a quote or an identifier char, so the
      # left shift in `$(( 1 << 3 ))` is not one. Reading either it or a `<<`
      # in prose as a heredoc sets `hd` to a terminator that never arrives, and
      # the extraction then swallows the whole SSOT tail into the copy.
      if (match(c, /(^|[^<])<<-?[ \t]*["'"'"']?[A-Za-z_][A-Za-z0-9_]*/)) {   # not a <<< here-string
        t = substr(c, RSTART, RLENGTH); sub(/^.*<<-?[ \t]*["'"'"']?/, "", t)
        if (t != "") hd = t
      }
      print
      if (c ~ /^}/ || (one && c ~ /\}[ \t]*$/)) exit   # `one`: a one-line f() { ...; }
      one = 0
    }
  ' "$1"
}

fn_line() { awk -v n="$2" '$0 ~ "^" n "[ \t]*\\(\\)" {print NR; exit}' "$1"; }

fail=0 checked=0 stale=0 skipped=0
for repo in "${repos[@]}"; do
  dir=$repo/$VENDOR_ROOT
  if [ ! -d "$dir" ]; then
    echo "note  $repo has no $VENDOR_ROOT -- skipped"
    continue
  fi
  rc=0
  grep -rl -- "^$BANNER_SSOT" "$dir" > "$tmp/dests" || rc=$?
  if [ "$rc" -gt 1 ]; then          # 1 is "no matches"; anything above is an error
    echo "FAIL  cannot scan $dir"
    fail=1
    continue
  fi
  while IFS= read -r dest; do
    [ -n "$dest" ] || continue
    # `$rest` is the banner's tail: "<path>" or "<path> (qualifier)". `$1=$1`
    # re-splits on any whitespace and rejoins on single spaces, so a tab or a
    # trailing space parses the same as awk's own `$4` did. awk, not grep -m1:
    # a file that somehow lost its banner leaves this empty and falls through to
    # the "names an SSOT that does not exist" arm, rather than aborting the
    # whole run under `set -e`.
    rest=$(awk -v p="^$BANNER_SSOT" '$0 ~ p {sub(p, ""); $1=$1; print; exit}' "$dest")
    rel=${rest%% *}
    qual=${rest#"$rel"}; qual=${qual# }

    # Hoisted above the two narrow checks: they read the SSOT too, so a missing
    # one is now a FAIL for every shape rather than only for whole-file copies.
    src=$ssot/$rel
    if [ ! -f "$src" ]; then
      echo "FAIL  $dest names an SSOT that does not exist: $src"
      fail=1
      continue
    fi

    # A partial extraction: compare only the function the qualifier names.
    if [ -n "$qual" ]; then
      name=${qual#(}; name=${name%)}
      if ! [[ $name =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        echo "skip  $dest -- qualifier $qual of $rel is not a function name, nothing to compare"
        skipped=$((skipped + 1))
        continue
      fi
      checked=$((checked + 1))
      extract_fn "$src" "$name" > "$tmp/want"
      extract_fn "$dest" "$name" > "$tmp/have"
      if [ ! -s "$tmp/want" ]; then
        echo "FAIL  $dest extracts $name, which $src no longer defines"
        fail=1
      elif [ ! -s "$tmp/have" ]; then
        echo "FAIL  $dest names extraction ($name) but no longer defines it"
        fail=1
      elif cmp -s "$tmp/want" "$tmp/have"; then
        echo "ok    $dest -- extraction ($name) matches $rel"
      else
        stale=$((stale + 1))
        if [ "$check_only" -eq 1 ]; then
          echo "DRIFT $dest extraction ($name) differs from $src"
          fail=1
        else
          # Splice the slice back in place: everything the copy wrote around the
          # function -- its banner, its why-this-is-extracted note -- survives.
          s=$(fn_line "$dest" "$name")
          e=$((s + $(wc -l < "$tmp/have") - 1))
          { head -n "$((s - 1))" "$dest"; cat "$tmp/want"; tail -n "+$((e + 1))" "$dest"; } > "$tmp/new"
          cat "$tmp/new" > "$dest"
          echo "sync  $dest -- extraction ($name) only"
        fi
      fi
      continue
    fi

    # Leading comment block only, so the marker cannot be forged from a body
    # line. A here-string, not a pipe: `set -o pipefail` would read grep -q's
    # early exit as the producer's SIGPIPE and silently invert the test.
    hdr=$(sed -n '/^[^#]/q;p' "$dest")
    if grep -q -- "$OPT_OUT" <<<"$hdr"; then
      # A stub's body was never upstream's, so there is nothing to diff. What is
      # assertable is that the bridge still has something to bridge: at least one
      # symbol its header backticks is still a function of the SSOT. At least
      # one, not all -- a prose header backticks variables and shell snippets
      # too (`_SC`, `[ -f ]` in gh-verify-skills' stub), so "all" would report
      # names the stub never promised. A stub that backticks nothing stays a
      # reported skip: it states no contract to check.
      names=$(grep -o '`[A-Za-z_][A-Za-z0-9_]*`' <<<"$hdr" | tr -d '`' | sort -u) || true
      if [ -z "$names" ]; then
        echo "skip  $dest -- header says 'Bridge only' and names no symbol of $rel to verify"
        skipped=$((skipped + 1))
        continue
      fi
      checked=$((checked + 1))
      live=
      for n in $names; do
        if grep -q "^${n}[[:space:]]*()" "$src"; then live=$n; break; fi
      done
      if [ -n "$live" ]; then
        echo "ok    $dest -- bridge stub for $rel, $live still defined there"
      else
        echo "FAIL  $dest bridges $rel, which defines none of: $(tr '\n' ' ' <<<"$names")"
        fail=1
      fi
      continue
    fi

    checked=$((checked + 1))
    render "$src" "$rel" > "$tmp/want"
    # Process substitution is safe here, unlike git discovery: the status under
    # test is cmp's own, and it sits in an `if`.
    if cmp -s <(strip_stamp < "$tmp/want") <(strip_stamp < "$dest"); then
      echo "ok    $dest"
      continue
    fi
    stale=$((stale + 1))
    if [ "$check_only" -eq 1 ]; then
      echo "DRIFT $dest differs from $src"
      fail=1
    else
      cat "$tmp/want" > "$dest"
      echo "sync  $dest"
    fi
  done < "$tmp/dests"
done

if [ "$check_only" -eq 1 ]; then
  if [ "$fail" -eq 0 ]; then
    echo "ok    $checked vendored file(s) match their SSOT, $skipped skipped"
  else
    echo "FAIL  $checked vendored file(s) checked, $stale drifted, $skipped skipped -- see the FAIL/DRIFT lines above"
  fi
else
  echo "ok    $checked vendored file(s) checked, $stale rewritten, $skipped skipped"
fi
exit "$fail"
