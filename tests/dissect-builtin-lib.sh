#!/usr/bin/env bash
# Runs the --self-test of harness:dissect-builtin's bundled script
# (harness-skills#69): promote-staging.sh publishes the two staged outputs file
# by file, and on an incomplete staging removes staging only.
#
# Offline: no network, no gh, no package install.
set -euo pipefail

root=$(git rev-parse --show-toplevel)
sh "$root/skills/dissect-builtin/lib/promote-staging.sh" --self-test
