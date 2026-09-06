#!/usr/bin/env bash
# Exercises skills/ai-context/lib/detect-context.sh -- the deterministic half
# of harness:ai-context Step 2 (harness-skills#3).
#
# The cases that matter are the ones prose kept getting wrong: an AGENTS.md
# symlinked to CLAUDE.md is ONE source, not a multiple-file WARN; an
# `@AGENTS.md` import shim is likewise an alias, and its line budget is the
# imported file's, not the shim's.
#
# Offline: no network, no gh, no package install.
set -euo pipefail

root=$(git rev-parse --show-toplevel)
script=$root/skills/ai-context/scripts/detect-context.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fail=0

get() { sed -n "s/^$2=//p" "$1"; }

check() {
  local label=$1 want=$2 got=$3
  if [ "$want" = "$got" ]; then
    printf 'ok    %s = %s\n' "$label" "$got"
  else
    printf 'FAIL  %s: expected %s, got %s\n' "$label" "$want" "$got"
    fail=1
  fi
}

# 1. AGENTS.md as a symlink to CLAUDE.md collapses to one source.
a=$work/symlink
mkdir -p "$a"
printf '# ctx\n' > "$a/CLAUDE.md"
ln -s CLAUDE.md "$a/AGENTS.md"
out=$work/symlink.out
bash "$script" --dir "$a" > "$out"
check "symlink kind"     claude            "$(get "$out" kind)"
check "symlink alias"    "$a/AGENTS.md"    "$(get "$out" aliases)"
check "symlink others"   ""                "$(get "$out" other_candidates)"

# 2. A CLAUDE.md whose whole body is `@AGENTS.md` is an alias too, and the
#    line budget is measured on the file a reader actually gets.
b=$work/import
mkdir -p "$b"
printf '@AGENTS.md\n' > "$b/CLAUDE.md"
seq 1 420 > "$b/AGENTS.md"
out=$work/import.out
bash "$script" --dir "$b" > "$out"
check "import alias"     "$b/AGENTS.md"    "$(get "$out" aliases)"
check "import lines"     420               "$(get "$out" line_count)"
check "import c7"        WARN              "$(get "$out" c7)"

# 2b. The same collapse in reverse, and a file that merely ENDS in `.md` is
#     not a shim.
b2=$work/import-reverse
mkdir -p "$b2"
printf '@GEMINI.md\n' > "$b2/AGENTS.md"
printf '# real content\n\nsee also foo.md\n' > "$b2/GEMINI.md"
out=$work/import-reverse.out
bash "$script" --dir "$b2" > "$out"
check "reverse path"     "$b2/AGENTS.md"   "$(get "$out" path)"
check "reverse alias"    "$b2/GEMINI.md"   "$(get "$out" aliases)"
check "reverse lines"    3                 "$(get "$out" line_count)"

# 3. Genuinely distinct files stay distinct, and priority picks CLAUDE.md.
c=$work/distinct
mkdir -p "$c"
printf '# claude\n' > "$c/CLAUDE.md"
printf '# gemini\n' > "$c/GEMINI.md"
out=$work/distinct.out
bash "$script" --dir "$c" > "$out"
check "distinct path"    "$c/CLAUDE.md"    "$(get "$out" path)"
check "distinct others"  "$c/GEMINI.md"    "$(get "$out" other_candidates)"

# 4. --type overrides the filename mapping; --file targets a non-standard name.
d=$work/typed
mkdir -p "$d"
printf '# ctx\n' > "$d/docs-context.md"
out=$work/typed.out
bash "$script" --file "$d/docs-context.md" --type agents > "$out"
check "forced kind"      agents            "$(get "$out" kind)"

# 4b. Sizing follows --file to that file's own project, not the caller's cwd.
f=$work/sized
mkdir -p "$f/.claude/agents"
printf '# ctx\n' > "$f/CLAUDE.md"
for i in $(seq 1 7); do printf '# agent\n' > "$f/.claude/agents/a$i.md"; done
out=$work/sized.out
bash "$script" --file "$f/CLAUDE.md" > "$out"
check "sized by target"  large             "$(get "$out" size_class)"

# 5. No context file is a non-zero exit, not an empty success.
e=$work/empty
mkdir -p "$e"
if bash "$script" --dir "$e" >/dev/null 2>&1; then
  printf 'FAIL  empty dir: expected non-zero exit\n'
  fail=1
else
  printf 'ok    empty dir exits non-zero\n'
fi

exit "$fail"
