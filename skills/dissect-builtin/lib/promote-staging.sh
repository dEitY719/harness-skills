#!/bin/sh
# promote-staging.sh — harness:dissect-builtin Step 3 (harness-skills#69).
#
#   sh promote-staging.sh <skill-name>            publish staging, then remove it
#   sh promote-staging.sh <skill-name> --abort    remove staging only
#   sh promote-staging.sh --self-test
#
# Step 2 writes README.md and PROMPT.md to docs/built-in-skills/.<skill-name>.staging/
# so a failed re-run cannot destroy an already-published pair (harness-skills#4,
# PR #40 codex BLOCKER). This script is the publish half of that rule:
#
# - Both files present: mkdir the target, overwrite each FILE, remove staging.
#   디렉터리째 `mv` 하면 대상이 이미 있을 때 그 안으로 중첩되므로 파일 단위로 옮긴다.
# - Either missing: 실패 시 — 스테이징만 지운다. The target is never touched, so the
#   previous outputs survive and no half-written directory appears.
#
# Paths are relative to the repository root from `git rev-parse --show-toplevel`,
# never $PWD. Exit: 0 promoted/aborted, 1 staging incomplete, 2 usage error.
set -eu

FILES="README.md PROMPT.md"

usage() { printf '[FAIL] usage: promote-staging.sh <skill-name> [--abort] | --self-test\n' >&2; exit 2; }

promote() {  # promote <skill-name> [--abort]
    name=$1 mode=${2:-}
    case "$name" in ''|.*|*/*) usage ;; esac
    case "$mode" in ''|--abort) ;; *) usage ;; esac
    root=$(git rev-parse --show-toplevel) || { printf '[FAIL] not inside a git repository\n' >&2; exit 2; }
    base=$root/docs/built-in-skills
    stage=$base/.$name.staging
    dest=$base/$name

    if [ "$mode" = --abort ]; then
        rm -rf -- "$stage"
        printf '[OK] aborted %s (staging removed)\n' "$name"
        return 0
    fi
    for f in $FILES; do
        [ -f "$stage/$f" ] || {
            rm -rf -- "$stage"
            printf '[FAIL] staging incomplete: missing %s\n' "$f"
            exit 1
        }
    done
    mkdir -p -- "$dest"
    for f in $FILES; do cp -f -- "$stage/$f" "$dest/$f"; done
    rm -rf -- "$stage"
    printf '[OK] promoted %s (README.md, PROMPT.md)\n' "$name"
}

self_test() {
    self=$(cd -- "$(dirname -- "$0")" && pwd)/$(basename -- "$0")
    t=$(mktemp -d)
    trap 'rm -rf -- "$t"' EXIT
    git init -q "$t"
    b=$t/docs/built-in-skills
    fail=0
    ck() {  # ck <label> <condition...>
        label=$1; shift
        if "$@"; then printf 'ok    %s\n' "$label"; else printf 'FAIL  %s\n' "$label"; fail=1; fi
    }
    run() { (cd "$t" && sh "$self" "$@") >"$t/out" 2>&1 && rc=0 || rc=$?; }

    # 1. Existing target is replaced file by file, not nested.
    mkdir -p "$b/x" "$b/.x.staging"
    echo old >"$b/x/README.md"; echo old >"$b/x/PROMPT.md"; echo keep >"$b/x/extra"
    echo new-r >"$b/.x.staging/README.md"; echo new-p >"$b/.x.staging/PROMPT.md"
    run x
    ck "promote exits 0" [ "$rc" = 0 ]
    ck "promote prints OK" grep -qF '[OK] promoted x (README.md, PROMPT.md)' "$t/out"
    ck "README replaced" grep -qx new-r "$b/x/README.md"
    ck "PROMPT replaced" grep -qx new-p "$b/x/PROMPT.md"
    ck "no nested staging dir" [ ! -e "$b/x/.x.staging" ]
    ck "staging removed" [ ! -e "$b/.x.staging" ]
    ck "unrelated file kept" [ -f "$b/x/extra" ]

    # 2. Incomplete staging: target untouched, staging removed, exit 1.
    mkdir -p "$b/.x.staging"; echo half >"$b/.x.staging/README.md"
    run x
    ck "incomplete exits 1" [ "$rc" = 1 ]
    ck "incomplete names the file" grep -qF '[FAIL] staging incomplete: missing PROMPT.md' "$t/out"
    ck "incomplete leaves target" grep -qx new-r "$b/x/README.md"
    ck "incomplete removes staging" [ ! -e "$b/.x.staging" ]

    # 3. Fresh skill with no prior target is created.
    mkdir -p "$b/.y.staging"; echo r >"$b/.y.staging/README.md"; echo p >"$b/.y.staging/PROMPT.md"
    run y
    ck "fresh promote creates README" [ -f "$b/y/README.md" ]
    ck "fresh promote creates PROMPT" [ -f "$b/y/PROMPT.md" ]

    # 4. --abort removes staging only.
    mkdir -p "$b/.x.staging"; echo r >"$b/.x.staging/README.md"
    run x --abort
    ck "abort exits 0" [ "$rc" = 0 ]
    ck "abort removes staging" [ ! -e "$b/.x.staging" ]
    ck "abort leaves target" grep -qx new-r "$b/x/README.md"

    # 5. Runs from a subdirectory: root comes from git, not $PWD.
    mkdir -p "$t/sub" "$b/.z.staging"; echo r >"$b/.z.staging/README.md"; echo p >"$b/.z.staging/PROMPT.md"
    (cd "$t/sub" && sh "$self" z) >"$t/out" 2>&1 && rc=0 || rc=$?
    ck "subdir run publishes at repo root" [ -f "$b/z/README.md" ]

    # 6. A name that could escape docs/built-in-skills/ is refused.
    run ../evil
    ck "path-like name exits 2" [ "$rc" = 2 ]

    [ "$fail" = 0 ] && printf 'ok    promote-staging.sh self-test\n'
    return "$fail"
}

case "${1:-}" in
    --self-test) self_test ;;
    ''|-*) usage ;;
    *) [ $# -le 2 ] || usage; promote "$@" ;;
esac
