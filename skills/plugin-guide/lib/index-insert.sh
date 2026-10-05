#!/bin/sh
# index-insert.sh — harness:plugin-guide Step 6 (harness-skills#69).
#
#   sh index-insert.sh <OUT>/README.md <PLUGIN> "<one-line Korean summary>"
#   sh index-insert.sh --self-test
#
# Adds `- [<PLUGIN>](./<PLUGIN>.md) — <summary>` inside the `## Index` list:
# after the last `- [...]` item and before the next `## ` header, never blindly
# at end-of-file. Idempotent: a README already linking `./<PLUGIN>.md` is left
# alone. A missing README, or one with no `## Index`, gets that section.
#
# Stdout: one word, `added` or `skipped`. Exit 2 on usage error.
set -eu

usage() { printf '[FAIL] usage: index-insert.sh <README> <PLUGIN> "<summary>" | --self-test\n' >&2; exit 2; }

insert() {
    readme=$1 plugin=$2 summary=$3
    if [ -z "$plugin" ] || [ -z "$summary" ]; then usage; fi
    line="- [$plugin](./$plugin.md) — $summary"
    if [ -f "$readme" ] && grep -qF "](./$plugin.md)" "$readme"; then
        echo skipped
        return 0
    fi
    if [ ! -f "$readme" ] || ! grep -q '^## Index[[:space:]]*$' "$readme"; then
        if [ -s "$readme" ]; then printf '\n' >>"$readme"; fi
        printf '## Index\n\n%s\n' "$line" >>"$readme"
        echo added
        return 0
    fi
    tmp=$readme.tmp.$$
    # ENVIRON, not -v: awk -v would interpret backslashes in the summary.
    LINE=$line awk '
        { l[NR] = $0 }
        END {
            for (i = 1; i <= NR; i++) if (l[i] ~ /^## Index[[:space:]]*$/) { s = i; break }
            e = NR + 1
            for (i = s + 1; i <= NR; i++) if (l[i] ~ /^## /) { e = i; break }
            at = s
            for (i = s + 1; i < e; i++) if (l[i] ~ /^- \[/) at = i
            for (i = 1; i <= NR; i++) {
                print l[i]
                if (i == at) { if (at == s) print ""; print ENVIRON["LINE"] }
            }
        }' "$readme" >"$tmp" && mv -f -- "$tmp" "$readme"
    echo added
}

self_test() {
    self=$(cd -- "$(dirname -- "$0")" && pwd)/$(basename -- "$0")
    t=$(mktemp -d)
    trap 'rm -rf -- "$t"' EXIT
    fail=0
    ck() {  # ck <label> <want> <got>
        if [ "$2" = "$3" ]; then printf 'ok    %s\n' "$1"
        else printf 'FAIL  %s\n--- want\n%s\n--- got\n%s\n' "$1" "$2" "$3"; fail=1; fi
    }

    # 1. Between the last item and the next header, not at EOF.
    printf '# Plugins\n\n## Index\n\n- [a](./a.md) — A\n\n## 문서 구성\n\ntext\n' >"$t/r1"
    ck "insert word" added "$(sh "$self" "$t/r1" b 'B 요약')"
    ck "insert position" "$(printf '# Plugins\n\n## Index\n\n- [a](./a.md) — A\n- [b](./b.md) — B 요약\n\n## 문서 구성\n\ntext')" "$(cat "$t/r1")"

    # 2. Re-run is idempotent.
    ck "re-run word" skipped "$(sh "$self" "$t/r1" b 'B 요약')"
    ck "re-run leaves one line" 1 "$(grep -c '(./b.md)' "$t/r1")"

    # 3. Missing README is created with the section.
    ck "create word" added "$(sh "$self" "$t/r2" c 'C')"
    ck "create content" "$(printf '## Index\n\n- [c](./c.md) — C')" "$(cat "$t/r2")"

    # 4. README without an Index gets one appended.
    printf '# Plugins\n' >"$t/r3"
    sh "$self" "$t/r3" d 'D' >/dev/null
    ck "append section" "$(printf '# Plugins\n\n## Index\n\n- [d](./d.md) — D')" "$(cat "$t/r3")"

    # 5. Empty Index section followed by a header.
    printf '## Index\n## Next\n' >"$t/r4"
    sh "$self" "$t/r4" e 'E' >/dev/null
    ck "empty section" "$(printf '## Index\n\n- [e](./e.md) — E\n## Next')" "$(cat "$t/r4")"

    # 6. Backslashes in the summary survive verbatim.
    printf '## Index\n\n- [a](./a.md) — A\n' >"$t/r5"
    sh "$self" "$t/r5" f 'C:\path' >/dev/null
    ck "backslash kept" '- [f](./f.md) — C:\path' "$(tail -n 1 "$t/r5")"

    [ "$fail" = 0 ] && printf 'ok    index-insert.sh self-test\n'
    return "$fail"
}

case "${1:-}" in
    --self-test) self_test ;;
    *) [ $# -eq 3 ] || usage; insert "$@" ;;
esac
