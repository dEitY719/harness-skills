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
set -euo pipefail

VENDOR_ROOT=lib/vendor
BANNER_SSOT='# SSOT: dEitY719/dotfiles '
BANNER_BY='dEitY719/harness-skills scripts/sync-shell-common-vendor.sh'

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

fail=0 checked=0 stale=0
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
    rel=$(awk -v p="^$BANNER_SSOT" '$0 ~ p {print $4; exit}' "$dest")
    src=$ssot/$rel
    if [ ! -f "$src" ]; then
      echo "FAIL  $dest names an SSOT that does not exist: $src"
      fail=1
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
    echo "ok    $checked vendored file(s) match their SSOT"
  else
    echo "FAIL  $stale of $checked vendored file(s) have drifted"
  fi
else
  echo "ok    $checked vendored file(s) checked, $stale rewritten"
fi
exit "$fail"
