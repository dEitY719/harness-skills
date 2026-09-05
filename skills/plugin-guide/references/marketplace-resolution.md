# Marketplace Resolution — Step 2 detail

Exact-match lookup for `PLUGIN` (and optional `MARKETPLACE`) against the keys of
`$CFG/plugins/installed_plugins.json`'s `plugins` object — Claude Code's own
installed-plugin record, keyed `"<plugin>@<marketplace>"`. Never `grep "PLUGIN@"`
— a plain substring/suffix grep for `skills` would also match
`example-skills@anthropic-agent-skills`. Use `jq` so only the plugin-name segment
before `@` is compared:

```bash
MATCHES=$(jq -r --arg p "$PLUGIN" \
  '.plugins | keys[] | select(split("@")[0] == $p)' \
  "$CFG/plugins/installed_plugins.json")
```

If that `jq` fails — the file is absent (no Claude Code config on this
machine, or a different harness) or it has no `.plugins` object — do **not**
fall through to the not-installed case below. An empty `$MATCHES` there reads
as "this plugin is not installed" and sends the user to install something that
may already be installed. Stop with the cause instead:

```
$CFG/plugins/installed_plugins.json 을 읽을 수 없습니다 (없거나 형식이 다름).
이 스킬은 Claude Code 의 설치 기록을 SSOT 로 씁니다. CLAUDE_CONFIG_DIR 이
맞는지 확인하거나, 다른 하네스라면 저장소 루트의 references/<harness>-tools.md
를 따르세요.
```

## Case A — `MARKETPLACE` given explicitly (`<plugin>@<marketplace>`)

Check that the exact string `"$PLUGIN@$MARKETPLACE"` is one of `$MATCHES`.

- Present → installed, proceed to Step 3.
- Absent → not-installed error case (below), with `MARKETPLACE` known.

## Case B — `MARKETPLACE` omitted (bare `<plugin>`)

Count the lines in `$MATCHES`:

- **Zero** → not-installed error case (below), with `MARKETPLACE` unknown.
- **One** → take `MARKETPLACE` from that entry's suffix after `@`. Proceed
  to Step 3.
- **Two or more** — the same plugin name is installed under multiple
  marketplaces (e.g. a machine with both
  `superpowers@claude-plugins-official` and `superpowers@superpowers-dev`).
  **Stop.** Never guess which one the user meant. Print the candidate list
  and ask the user to re-run with an explicit `<plugin>@<marketplace>`:

  ```
  플러그인 <plugin> 이 여러 marketplace에 설치되어 있습니다:
    - <plugin>@<marketplace-1>
    - <plugin>@<marketplace-2>
  재실행: /harness:plugin-guide <plugin>@<marketplace-N>
  ```

## Not-installed error case

- **`MARKETPLACE` known** (Case A, or Case B narrowed by the user's own
  `@marketplace` suffix): read `owner/repo` from
  `$CFG/plugins/known_marketplaces.json`'s `[MARKETPLACE].source.repo` and print
  the install instructions block from
  `references/help.md` ("설치 안내") filled in with `<plugin>@<marketplace>` +
  `<owner/repo>`, then **stop** — never run `/plugin install` yourself.
- **`MARKETPLACE` unknown** (Case B, zero matches): there is no `owner/repo`
  to look up — printing a fabricated install command would be a guess. Stop
  with:

  ```
  플러그인 <plugin> 이 설치 목록(installed_plugins.json)에 없고 marketplace
  정보도 없습니다. 정확한 marketplace를 알고 있다면 <plugin>@<marketplace>
  형태로 재실행하세요.
  ```
