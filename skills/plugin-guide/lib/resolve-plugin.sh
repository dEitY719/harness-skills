#!/bin/sh
# resolve-plugin.sh — harness:plugin-guide Step 2 (harness-skills#69).
#
#   sh resolve-plugin.sh <plugin>[@<marketplace>]
#   sh resolve-plugin.sh --self-test
#
# Exact-matches against `claude plugin list --json`'s `id` with jq: `<plugin>@`
# as a prefix, or the whole id when `@<marketplace>` is given. Never a substring
# grep -- `skills` would match `example-skills@...`. An id listed at both user and
# project scope is one candidate; project scope wins for INSTALL_PATH.
#
# Stdout on success:  MARKETPLACE=<m>
#                     INSTALL_PATH=<p>
# Exit  0 one match | 1 not installed | 2 ambiguous (re-run with @<marketplace>)
#       3 jq missing or `claude plugin list --json` failed (cause, not "not installed")
#       4 usage
set -eu

usage() { printf '[FAIL] usage: resolve-plugin.sh <plugin>[@<marketplace>] | --self-test\n' >&2; exit 4; }

resolve() {
    arg=$1
    case "$arg" in ''|@*|*@*@*) usage ;; esac
    plugin=${arg%%@*}
    mkt=''
    case "$arg" in *@*) mkt=${arg#*@}; [ -n "$mkt" ] || usage ;; esac
    command -v jq >/dev/null 2>&1 || { printf '[FAIL] jq not found\n' >&2; exit 3; }
    list=$(claude plugin list --json 2>/dev/null) || {
        printf '[FAIL] claude plugin list --json failed (not a Claude Code session?) -- see references/<harness>-tools.md\n' >&2
        exit 3
    }
    ids=$(printf '%s' "$list" | jq -r --arg p "$plugin" --arg m "$mkt" \
        '[.[] | .id | select(startswith($p + "@")) | select($m == "" or . == ($p + "@" + $m))] | unique | .[]') || {
        printf '[FAIL] claude plugin list --json returned unparsable output\n' >&2
        exit 3
    }
    n=$(printf '%s' "$ids" | grep -c . || :)
    case "$n" in
        0) printf '[FAIL] not installed: %s\n' "$arg"; exit 1 ;;
        1) ;;
        *) printf '[FAIL] ambiguous: %s -- re-run with <plugin>@<marketplace>\n' "$(printf '%s' "$ids" | tr '\n' ' ' | sed 's/ $//')"
           exit 2 ;;
    esac
    path=$(printf '%s' "$list" | jq -r --arg id "$ids" \
        '[.[] | select(.id == $id)] | sort_by(.scope != "project") | .[0].installPath')
    printf 'MARKETPLACE=%s\nINSTALL_PATH=%s\n' "${ids#*@}" "$path"
}

self_test() {
    self=$(cd -- "$(dirname -- "$0")" && pwd)/$(basename -- "$0")
    t=$(mktemp -d)
    trap 'rm -rf -- "$t"' EXIT
    mkdir "$t/bin"
    # A fake `claude` on PATH stands in for the CLI; the fixture is its output.
    cat >"$t/bin/claude" <<'EOF'
#!/bin/sh
[ -f "$FAKE_LIST" ] || exit 1
cat "$FAKE_LIST"
EOF
    chmod +x "$t/bin/claude"
    cat >"$t/list.json" <<'EOF'
[
 {"id": "skills@one", "scope": "user", "installPath": "/c/skills/one"},
 {"id": "example-skills@anthropic", "scope": "user", "installPath": "/c/ex"},
 {"id": "dup@m", "scope": "user", "installPath": "/c/dup/user"},
 {"id": "dup@m", "scope": "project", "installPath": "/c/dup/project"},
 {"id": "sp@a", "scope": "user", "installPath": "/c/sp/a"},
 {"id": "sp@b", "scope": "user", "installPath": "/c/sp/b"}
]
EOF
    fail=0
    expect() {  # expect <label> <want-rc> <want-substring> <arg>
        out=$(PATH="$t/bin:$PATH" FAKE_LIST=${FIXTURE:-$t/list.json} sh "$self" "$4" 2>&1) && rc=0 || rc=$?
        if [ "$rc" = "$2" ] && printf '%s' "$out" | grep -qF -- "$3"; then
            printf 'ok    %s\n' "$1"
        else
            printf 'FAIL  %s (rc=%s, wanted %s and %s)\n%s\n' "$1" "$rc" "$2" "$3" "$out"; fail=1
        fi
    }
    expect "bare name, no substring match" 0 'INSTALL_PATH=/c/skills/one' skills
    expect "bare name binds marketplace" 0 'MARKETPLACE=one' skills
    expect "repeated id is one candidate, project wins" 0 'INSTALL_PATH=/c/dup/project' dup
    expect "two marketplaces is ambiguous" 2 '[FAIL] ambiguous: sp@a sp@b' sp
    expect "explicit marketplace disambiguates" 0 'INSTALL_PATH=/c/sp/b' sp@b
    expect "unknown plugin" 1 '[FAIL] not installed: nope' nope
    expect "suffix is not a match" 1 '[FAIL] not installed: example' example
    expect "wrong marketplace" 1 '[FAIL] not installed: sp@c' sp@c
    FIXTURE=$t/missing expect "CLI failure is not 'not installed'" 3 'list --json failed' skills
    expect "empty marketplace is usage" 4 'usage' 'sp@'
    [ "$fail" = 0 ] && printf 'ok    resolve-plugin.sh self-test\n'
    return "$fail"
}

case "${1:-}" in
    --self-test) self_test ;;
    ''|-*) usage ;;
    *) [ $# -eq 1 ] || usage; resolve "$1" ;;
esac
