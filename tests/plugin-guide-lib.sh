#!/usr/bin/env bash
# Runs the --self-test of harness:plugin-guide's bundled scripts
# (harness-skills#69): resolve-plugin.sh exact-matches the installed-plugin id
# (never a substring grep), and index-insert.sh adds one idempotent line inside
# the README's `## Index` list rather than at end-of-file.
#
# Offline: a fake `claude` on PATH stands in for the CLI. Needs jq.
set -euo pipefail

root=$(git rev-parse --show-toplevel)
fail=0
for s in resolve-plugin.sh index-insert.sh; do
  sh "$root/skills/plugin-guide/lib/$s" --self-test || fail=1
done
exit "$fail"
