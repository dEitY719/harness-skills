// Runtime contract. The Claude Code Workflow host evaluates this file as an
// async function body and injects its API as globals: `phase`, `agent`,
// `parallel`, `log`, `args`. They are deliberately not imported - there is no
// import surface for them - and top-level `await` / `return` are legal here,
// which is why `node --check` cannot lint this file. Callers invoke it as
// `Workflow({ name: 'harness:harness-refactor', args: { changes: [...], rejected: [...] } })`:
// the `harness:` prefix is the plugin name and `meta.name` below stays bare.
// .github/workflows/skill-check.yml asserts both halves of that contract by
// stripping this `export const meta` line and compiling the remainder as an
// AsyncFunction body - the same shape `workflows/harness-legacy-check.js`
// already ships and passes that check with today.
//
// `args.changes` / `args.rejected` are the two lists `harness:harness-refactor`
// Step 2 classifies from the harness-legacy-check report: arrays of
// `{ file, description }` (rejected entries also carry `reason`). Nothing in
// this file is regenerated per run - only that small data payload varies, and
// it arrives through `args` instead of being baked into a freshly authored
// copy of this script.
export const meta = {
  name: 'harness-refactor',
  description: 'Apply low-risk harness improvements classified from the latest harness-legacy-check audit',
  phases: [
    { title: 'Pre-flight',     detail: 'Verify target files exist, create archive directory' },
    { title: 'Apply Changes',  detail: 'Parallel agents modify non-overlapping file groups' },
    { title: 'Verify',         detail: 'Line count validation on all modified files' },
    { title: 'Final Report',   detail: 'Change summary, behavior delta, smoke-test prompts' },
  ],
}

const rawChanges = (args && args.changes) || []
const rejected = (args && args.rejected) || []
const today = new Date().toISOString().slice(0, 10)
const ARCHIVE = `.claude/archive/harness-refactor-${today}`

// A change's `file` must stay inside the project tree: no absolute path, no
// `..` segment. Step 2's classification is model output, not a security
// boundary, so this is cheap insurance against one bad entry sending an
// agent outside the repo.
const isSafePath = (f) => typeof f === 'string' && f.length > 0 && !f.startsWith('/') && !f.split('/').includes('..')
// Model-authored text lands verbatim inside a template-literal prompt below;
// a stray backtick in a description would close that literal early and a
// markdown fence would bleed formatting into the rest of the prompt.
const clean = (s) => String(s == null ? '' : s).replace(/`/g, "'")
const changes = rawChanges.filter((c) => isSafePath(c && c.file))
const unsafe = rawChanges.filter((c) => !isSafePath(c && c.file))
if (unsafe.length > 0) {
  log(`Rejected ${unsafe.length} change(s) with an unsafe path (absolute or containing '..'): ${unsafe.map((c) => c && c.file).join(', ')}`)
}

if (changes.length === 0) {
  log('No changes in args.changes - nothing to apply. Run Step 2 classification first.')
} else {
  // ─── Phase 1: Pre-flight ────────────────────────────────────────────────
  phase('Pre-flight')

  const preflightRaw = await agent(`
You are a PRE-FLIGHT agent for a low-risk harness refactor. Verify every
target file below exists in the current project, and create the archive
directory ${ARCHIVE} (mkdir -p). Do not move or modify any file yet.

Target files:
${changes.map((c) => `- ${clean(c.file)}: ${clean(c.description)}`).join('\n')}

Reply with ONLY a JSON object as your last line, no other trailing text:
{"ok": true} if every file exists, or {"ok": false, "missing": ["<file>", ...]}
otherwise.
`, { label: 'preflight', phase: 'Pre-flight' })

  let preflight
  try {
    preflight = JSON.parse(String(preflightRaw).trim().split('\n').pop())
  } catch {
    preflight = { ok: false, missing: ['<pre-flight result was not valid JSON>'] }
  }

  if (!preflight.ok) {
    // Nothing has been archived yet at this point - Apply Changes is what
    // touches disk - so there is no partial-archive path to report here.
    throw new Error(`Pre-flight blocked: missing file(s) ${JSON.stringify(preflight.missing || [])}. Stopping before any edit.`)
  }

  // ─── Phase 2: Apply Changes ─────────────────────────────────────────────
  phase('Apply Changes')

  // One group per target file, so parallel agents never race on the same
  // path. Two classified changes to the same file merge into one group.
  const byFile = new Map()
  for (const c of changes) {
    const list = byFile.get(c.file) || []
    list.push(c)
    byFile.set(c.file, list)
  }
  const groups = [...byFile.entries()]

  const results = await parallel(groups.map(([file, group]) => () => agent(`
You are an APPLY-CHANGES agent for a low-risk harness refactor. Before
editing ${clean(file)}, copy its current content into ${ARCHIVE}/${clean(file)}
(preserving directory structure), then apply the following change(s) exactly:

${group.map((c) => `- ${clean(c.description)}`).join('\n')}

Return one CHANGE_SCHEMA result: { file, action, archived_to, lines_before, lines_after }.
`, { label: `apply-${file.replace(/[^a-zA-Z0-9_-]/g, '-')}`, phase: 'Apply Changes' })))

  // ─── Phase 3: Verify ─────────────────────────────────────────────────────
  phase('Verify')

  await agent(`
You are a VERIFY agent. For each changed file below, run wc -l and confirm it
matches the reported lines_after, and confirm any references/ file the change
claims to create actually exists.

Changed files:
${JSON.stringify(results, null, 2)}
`, { label: 'verify', phase: 'Verify' })

  // ─── Phase 4: Final Report ───────────────────────────────────────────────
  phase('Final Report')

  await agent(`
You are the FINAL REPORT agent. Produce the run summary:
- Change list with the reason each was applied
- Behavior delta per file
- 5 smoke-test prompts a human can run to sanity-check the result
- A "Human Approval Required" section listing exactly the rejected findings
  below - classification-rules.md forbade automating these, so this workflow
  never touched them

Applied changes:
${JSON.stringify(results, null, 2)}

Human Approval Required (forbidden by classification, never applied):
${rejected.length > 0 ? rejected.map((r) => `- ${clean(r.file)}: ${clean(r.description)}${r.reason ? ` (${clean(r.reason)})` : ''}`).join('\n') : '(none)'}
`, { label: 'final-report', phase: 'Final Report' })
}
