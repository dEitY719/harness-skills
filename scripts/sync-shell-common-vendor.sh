#!/usr/bin/env bash
# Regenerate the vendored copies of dEitY719/dotfiles' shell-common functions.
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
# Only files a consumer ALREADY vendors are refreshed. This never adds one:
# what a repo vendors is that repo's decision, not this script's.
set -euo pipefail

VENDOR_SUBDIR=lib/vendor/shell-common/functions
SSOT_SUBDIR=shell-common/functions

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

src_dir=$ssot/$SSOT_SUBDIR
if [ ! -d "$src_dir" ]; then
  echo "FAIL  no SSOT at $src_dir -- pass --ssot <dotfiles-checkout>" >&2
  exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
stamp=$(date -u +%Y-%m-%dT%H:%MZ)

render() {  # render <ssot-file> <name> -- the vendored file, banner under the shebang
  local src=$1 name=$2 rest=1
  if head -n 1 "$src" | grep -q '^#!'; then
    head -n 1 "$src"
    rest=2
  fi
  printf '# VENDORED — do not edit here.\n'
  printf '# SSOT: dEitY719/dotfiles %s/%s\n' "$SSOT_SUBDIR" "$name"
  printf '# Synced %s by scripts/sync-shell-common-vendor.sh — re-run that script to update.\n' "$stamp"
  tail -n "+$rest" "$src"
}

# The stamp is provenance, not content: comparing it would make every copy
# read as drifted one minute after a sync.
strip_stamp() { sed 's|^# Synced .* by scripts/sync-shell-common-vendor\.sh .*$|# Synced <stamp>|'; }

fail=0 checked=0 stale=0
for repo in "${repos[@]}"; do
  dir=$repo/$VENDOR_SUBDIR
  if [ ! -d "$dir" ]; then
    echo "note  $repo vendors nothing at $VENDOR_SUBDIR -- skipped"
    continue
  fi
  for dest in "$dir"/*.sh; do
    [ -e "$dest" ] || continue
    name=${dest##*/}
    src=$src_dir/$name
    if [ ! -f "$src" ]; then
      echo "FAIL  $dest has no SSOT at $src"
      fail=1
      continue
    fi
    checked=$((checked + 1))
    render "$src" "$name" > "$tmp/want"
    strip_stamp < "$tmp/want" > "$tmp/want.s"
    strip_stamp < "$dest" > "$tmp/have.s"
    if cmp -s "$tmp/want.s" "$tmp/have.s"; then
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
  done
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
