// Runtime contract. The Claude Code Workflow host evaluates this file as an
// async function body and injects its API as globals: `phase`, `agent`,
// `parallel`, `log`, `args`. They are deliberately not imported - there is no
// import surface for them - and top-level `await` / `return` are legal here,
// which is why `node --check` cannot lint this file. Callers invoke it as
// `Workflow({ name: 'harness:harness-refactor', args: { changes: [...] } })`:
// the `harness:` prefix is the plugin name and `meta.name` below stays bare.
// .github/workflows/skill-check.yml asserts both halves of that contract.
//
// `args.changes` is the change list `harness:harness-refactor` Step 2
// classifies from the harness-legacy-check report: an array of
// `{ file, description }`. Nothing in this file is regenerated per run -
// only that small data payload varies, and it arrives through `args`
// instead of being baked into a freshly authored copy of this script.
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

const changes = (args && args.changes) || []
const today = new Date().toISOString().slice(0, 10)
const ARCHIVE = `.claude/archive/harness-refactor-${today}`

if (changes.length === 0) {
  log('No changes in args.changes - nothing to apply. Run Step 2 classification first.')
} else {
  // ─── Phase 1: Pre-flight ────────────────────────────────────────────────
  phase('Pre-flight')

  await agent(`
You are a PRE-FLIGHT agent for a low-risk harness refactor. Verify every
target file below exists in the current project, and create the archive
directory ${ARCHIVE} (mkdir -p). Do not move or modify any file yet.

Target files:
${changes.map((c) => `- ${c.file}: ${c.description}`).join('\n')}

Report any missing file as a blocker instead of guessing a replacement path.
`, { label: 'preflight', phase: 'Pre-flight' })

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
editing ${file}, copy its current content into ${ARCHIVE}/${file}
(preserving directory structure), then apply the following change(s) exactly:

${group.map((c) => `- ${c.description}`).join('\n')}

Return one CHANGE_SCHEMA result: { file, action, archived_to, lines_before, lines_after }.
`, { label: `apply-${file}`, phase: 'Apply Changes' })))

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
- A "Human Approval Required" section listing every finding the report raised
  that classification-rules.md forbids from automation - this workflow never
  touches those files

Applied changes:
${JSON.stringify(results, null, 2)}
`, { label: 'final-report', phase: 'Final Report' })
}
