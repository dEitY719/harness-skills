#!/usr/bin/env bash
# Exercises skills/ai-context/scripts/detect-context.sh -- the deterministic half
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

# 6. ...but it still prints the fields, because `create` is the branch the
#    resolution matrix sends that row to and it needs size_class to pick a
#    template (PR #38 review, codex BLOCKER).
#    `kind` must be concrete or `create` has neither a template nor a target
#    filename, so it defaults to the head of the documented priority order.
out=$work/empty.out
bash "$script" --dir "$e" > "$out" 2>/dev/null || :
check "empty dir kind"       claude  "$(get "$out" kind)"
check "empty dir size_class" simple  "$(get "$out" size_class)"
check "empty dir path"       ""      "$(get "$out" path)"
check "empty dir line_count" 0       "$(get "$out" line_count)"

# 6b. `create --file NEW.md` names a target that does not exist yet. That is
#     the create case, not a hard error — the name carries the adapter, and
#     the exit status stays 1 so check/refactor still abort.
out=$work/newfile.out
bash "$script" --file "$e/AGENTS.md" > "$out" 2>/dev/null || :
check "create --file kind" agents        "$(get "$out" kind)"
#     ...and the requested destination survives, so a non-standard target is
#     not silently replaced by the canonical one (PR #38 review, codex BLOCKER).
check "create --file path" "$e/AGENTS.md" "$(get "$out" path)"
out=$work/custom.out
bash "$script" --file "$e/custom.md" --type agents > "$out" 2>/dev/null || :
check "create --file custom path" "$e/custom.md" "$(get "$out" path)"
check "create --file custom kind" agents         "$(get "$out" kind)"
if bash "$script" --file "$e/AGENTS.md" >/dev/null 2>&1; then
  printf 'FAIL  create --file on a missing target: expected non-zero exit\n'
  fail=1
else
  printf 'ok    create --file on a missing target exits non-zero\n'
fi

# 7. Only the three documented adapters are accepted; an unlisted --type must
#    fail here rather than reach dispatch (PR #38 review, codex BLOCKER).
if bash "$script" --type bogus --dir "$e" >/dev/null 2>&1; then
  printf 'FAIL  --type bogus: expected rejection\n'
  fail=1
else
  printf 'ok    --type bogus rejected\n'
fi

# 7b. `--type` wins on EVERY path, never overwritten by a filename or by the
#     create-path default. Every assignment to it is guarded by `[ -n "$type" ]`
#     and this pins that (PR #38 review, agy read it the other way round).
out=$work/forced-existing.out
bash "$script" --dir "$a" --type gemini > "$out"
check "--type beats filename" gemini "$(get "$out" kind)"
out=$work/forced-empty.out
bash "$script" --dir "$e" --type agents > "$out" 2>/dev/null || :
check "--type beats create default" agents "$(get "$out" kind)"
for t in agents claude gemini; do
  bash "$script" --type "$t" --dir "$e" >/dev/null 2>&1 && rc=0 || rc=$?
  # rc 1 = "no context file" (expected here); rc 2 = argument rejected.
  check "--type $t accepted" 1 "$rc"
done

# 7c. The mixed case A-CL5 must NOT call parity: an alias pair plus a genuinely
#     independent third file. `aliases` is non-empty and `other_candidates` is
#     too, so reading `aliases` alone would falsely PASS while the third file
#     drifts (PR #38 review, codex BLOCKER + FOLLOW-UP).
m=$work/mixed
mkdir -p "$m"
printf '# ctx\n' > "$m/CLAUDE.md"
printf '@CLAUDE.md\n' > "$m/GEMINI.md"
printf '# a different document entirely\n' > "$m/AGENTS.md"
out=$work/mixed.out
bash "$script" --dir "$m" > "$out"
check "mixed path"    "$m/CLAUDE.md" "$(get "$out" path)"
check "mixed aliases" "$m/GEMINI.md" "$(get "$out" aliases)"
check "mixed others"  "$m/AGENTS.md" "$(get "$out" other_candidates)"
grep -q 'other_candidates' "$root/skills/ai-context/references/checks.md" || {
  printf 'FAIL  A-CL5 no longer consults other_candidates, so the mixed case can PASS again\n'
  fail=1
}

# 7d. Two files that both import the SAME third file are aliases of each other,
#     not distinct candidates — neither imports the other, so comparing only
#     against the primary's own name missed it (PR #38 review, codex BLOCKER).
sh3=$work/shared-import
mkdir -p "$sh3"
printf '# the real document\n' > "$sh3/SHARED.md"
printf '@SHARED.md\n' > "$sh3/CLAUDE.md"
printf '@SHARED.md\n' > "$sh3/AGENTS.md"
out=$work/shared.out
bash "$script" --dir "$sh3" > "$out"
check "shared-import aliases" "$sh3/AGENTS.md" "$(get "$out" aliases)"
check "shared-import others"  ""               "$(get "$out" other_candidates)"

# 7e. A `--file` naming a non-standard filename with no --type must not report
#     `kind=unknown`, which is not an adapter (PR #38 review, agy BLOCKER).
out=$work/unknown.out
bash "$script" --file "$e/notes.md" > "$out" 2>/dev/null || :
check "custom name kind" claude       "$(get "$out" kind)"
check "custom name path" "$e/notes.md" "$(get "$out" path)"

# 8. `die` reports the message only — the exit code used to leak into it via
#    "$*", so every `die "msg" 1` printed a stray trailing 1.
msg=$(bash "$script" --dir "$e" 2>&1 >/dev/null) || :
case "$msg" in
  *' 1') printf 'FAIL  die leaked the exit code into the message: %s\n' "$msg"; fail=1 ;;
  *)     printf 'ok    die message carries no exit code\n' ;;
esac

exit "$fail"
