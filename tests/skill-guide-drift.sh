#!/usr/bin/env bash
# docs/skill-guides/<n>.{md,html} is a hand-written guide for skills/<n>/.
# Nothing generates it, so it drifts silently: harness-skills#46 found the
# plugin-guide pair documenting a `claude/plugin/plugins.json` inventory that
# no version of that SKILL.md ever read.
#
# This asserts ONE narrow thing rather than "the guide matches the skill":
# every config file a guide names by path must appear somewhere under the
# skill it documents. A guide that names a mechanism its skill does not have
# is describing something that is not there -- which is the whole #46 defect
# class, and the one shape that is cheap to check with no false positives.
#
# Deliberately NOT a freshness check. A sibling repo (visuals-skills#38) hit
# this same class and found the stale guide's commit was NEWER than the
# SKILL.md it had drifted from, so mtimes and commit order prove nothing. Only
# content does. The general "guide agrees with skill" check is a design
# question tracked in visuals-skills#29; this is the piece that needs no
# design.
set -euo pipefail

root=$(git rev-parse --show-toplevel)
cd "$root"
fail=0

shopt -s nullglob
guides=(docs/skill-guides/*.md)
if [ "${#guides[@]}" -eq 0 ]; then
  echo "ok    no skill guides tracked"
  exit 0
fi

for guide in "${guides[@]}"; do
  n=$(basename "$guide" .md)
  if [ ! -d "skills/$n" ]; then
    echo "FAIL  docs/skill-guides/$n.md documents no skill (skills/$n/ is missing)"
    fail=1
    continue
  fi

  # Both carriers, because they drift together: #46's .html twin repeated
  # every stale claim the .md made, and fixing one would have left the
  # published page wrong.
  # `|| true`: a guide naming no .json at all is the normal case, and grep
  # exiting 1 for it would take `set -e` with it.
  named=$(grep -ohE '`[A-Za-z0-9_./-]+\.json`' "docs/skill-guides/$n.md" \
            "docs/skill-guides/$n.html" 2>/dev/null | tr -d '`' | sort -u || true)

  while IFS= read -r j; do
    [ -n "$j" ] || continue
    if ! grep -rqF -- "$j" "skills/$n/"; then
      echo "FAIL  docs/skill-guides/$n names '$j', which appears nowhere in skills/$n/"
      fail=1
    fi
  done <<<"$named"
done

[ "$fail" -eq 0 ] || exit 1
echo "ok    every skill guide's config paths exist in the skill it documents"
