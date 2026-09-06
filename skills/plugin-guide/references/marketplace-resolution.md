# Marketplace Resolution — Step 2 detail

Exact-match lookup for `PLUGIN` (and optional `MARKETPLACE`) against
`claude plugin list --json`'s entries — Claude Code's own installed-plugin
inventory, each entry's `id` shaped `"<plugin>@<marketplace>"`. Never
`grep "PLUGIN@"` — a plain substring/suffix grep for `skills` would also match
`example-skills@anthropic-agent-skills`. Use `jq` so only the plugin-name
segment before `@` is compared:

```bash
MATCHES=$(claude plugin list --json | jq -c --arg p "$PLUGIN" \
  '.[] | select(.id | split("@")[0] == $p)')
```

`-c` keeps each matched entry as one compact JSON object per line (not just
its `id`) — `.installPath` is read off it below, no second CLI call needed.
The same `id` can appear more than once (a plugin installed at both `user`
and `project` scope) — that is **not** marketplace ambiguity, so dedupe by
`id` before counting candidates:

```bash
IDS=$(printf '%s\n' "$MATCHES" | jq -r '.id' | sort -u)
```

To resolve one `id` to the entry Step 3 reads `installPath` from — preferring
`project` scope over `user` when the `id` repeats with the same or a
different `installPath`:

```bash
pick_entry() {  # $1 = exact id, e.g. "$PLUGIN@$MARKETPLACE"
  printf '%s\n' "$MATCHES" | jq -cs --arg id "$1" \
    '[.[] | select(.id == $id)] | sort_by(.scope != "project") | .[0]'
}
```

If `claude plugin list --json` itself fails (not a Claude Code session, or the
CLI is unavailable) do **not** fall through to the not-installed case below —
an empty `$MATCHES` there reads as "this plugin is not installed" and sends
the user to install something that may already be installed. Stop with the
cause instead:

```
claude plugin list --json 를 실행할 수 없습니다. 이 스킬은 Claude Code 의 설치
기록을 SSOT 로 씁니다. 다른 하네스라면 저장소 루트의
references/<harness>-tools.md 를 따르세요.
```

## Case A — `MARKETPLACE` given explicitly (`<plugin>@<marketplace>`)

Check that the exact string `"$PLUGIN@$MARKETPLACE"` is one of `$IDS`.

- Present → `MATCH=$(pick_entry "$PLUGIN@$MARKETPLACE")`;
  `INSTALL_PATH=$(printf '%s' "$MATCH" | jq -r .installPath)`. Proceed to
  Step 3.
- Absent → not-installed error case (below), with `MARKETPLACE` known.

## Case B — `MARKETPLACE` omitted (bare `<plugin>`)

Count the (deduped) lines in `$IDS`:

- **Zero** → not-installed error case (below), with `MARKETPLACE` unknown.
- **One** → `MATCH=$(pick_entry "$IDS")`; take `MARKETPLACE` from `$IDS`'s
  suffix after `@` and `INSTALL_PATH` from `$MATCH.installPath`. Proceed to
  Step 3.
- **Two or more** — the same plugin name is installed under multiple
  marketplaces (e.g. a machine with both
  `superpowers@claude-plugins-official` and `superpowers@superpowers-dev`).
  **Stop.** Never guess which one the user meant. Print the candidate list
  (each line of `$IDS`) and ask the user to re-run with an explicit
  `<plugin>@<marketplace>`:

  ```
  [FAIL] harness:plugin-guide — 여러 marketplace 에 설치됨 (Step 2 resolve)
  플러그인 <plugin> 이 여러 marketplace에 설치되어 있습니다:
    - <plugin>@<marketplace-1>
    - <plugin>@<marketplace-2>
  재실행: /harness:plugin-guide <plugin>@<marketplace-N>
  ```

## Not-installed error case

- **`MARKETPLACE` known** (Case A, or Case B narrowed by the user's own
  `@marketplace` suffix): `claude plugin marketplace list --json` returns an
  **array** of `{name, source, repo, installLocation}` objects — find the one
  matching `MARKETPLACE`:

  ```bash
  OWNER_REPO=$(claude plugin marketplace list --json | jq -r \
    --arg m "$MARKETPLACE" '.[] | select(.name == $m) | .repo')
  ```

  Print the install instructions block from `references/help.md` ("설치
  안내") filled in with `<plugin>@<marketplace>` + `$OWNER_REPO`, prefixed
  with the `[FAIL]` shape, then **stop** — never run `/plugin install`
  yourself.
- **`MARKETPLACE` unknown** (Case B, zero matches): there is no `owner/repo`
  to look up — printing a fabricated install command would be a guess. Stop
  with:

  ```
  [FAIL] harness:plugin-guide — 미설치, marketplace 불명 (Step 2 resolve)
  플러그인 <plugin> 이 설치 목록(claude plugin list)에 없고 marketplace 정보도
  없습니다. 정확한 marketplace를 알고 있다면 <plugin>@<marketplace> 형태로
  재실행하세요.
  ```
