# Phase 13: Documentation & Legal - Research

**Researched:** 2026-04-27
**Domain:** Documentation accuracy — Markdown files, YAML frontmatter, traceability tables
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Traceability table (DOC-01)**
- Update archived v1.0-REQUIREMENTS.md only (active REQUIREMENTS.md already has v1.1 content)
- Mark all 33 v1.0 requirement entries as Complete (all were shipped)
- Keep arrow notation for phase reassignments (e.g., "Phase 4 -> Phase 10") to preserve history
- Leave section ordering as-is (R8 before R9 is original authoring order)

**SUMMARY fields (DOC-02)**
- Add `requirements-completed` as YAML list format in Phase 04 SUMMARY frontmatter
- Per-plan granularity: each SUMMARY lists only the requirements that specific plan addressed
  - 04-00 (test stubs): `requirements-completed: []` (empty — prep work only)
  - 04-01 (proxy/AI service): map to R2.5, R5.1
  - 04-02 (AI features): map to R2.1, R2.2, R2.3, R2.4
  - 04-03 (API runner): map to R5.2, R5.3
- Phase 04 only — do not backfill other phases (not tracked as tech debt)

**Launch date (DOC-03)**
- Replace [Launch Date] with 2026-04-27 everywhere it appears
- Fix in legal docs: docs/legal/terms-of-service.md, docs/legal/privacy-policy.md
- Also fix in .planning/ files: REQUIREMENTS.md, ROADMAP.md, PROJECT.md, MILESTONES.md, and any others found via grep
- Quick scan both legal docs for any other bracket placeholders or TODOs while fixing the date

**Commit strategy**
- One commit per DOC requirement (3 commits total)
- DOC-01: traceability table update
- DOC-02: Phase 04 SUMMARY field additions
- DOC-03: [Launch Date] replacement across all files

**Verification approach**
- Grep-based automated checks after implementation:
  - No remaining "Pending" status in v1.0-REQUIREMENTS.md traceability table
  - No remaining `[Launch Date]` string anywhere in the repo
  - `requirements-completed` field present in all 4 Phase 04 SUMMARY files

### Claude's Discretion
- Exact requirement-to-plan mapping for 04-01/04-02/04-03 (verify by reading SUMMARY content)
- Whether to fix minor formatting issues noticed while editing targeted files
- Order of DOC requirement execution

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DOC-01 | REQUIREMENTS.md traceability updated — all 33 v1.0 entries reflect actual completion status | Traceability table in v1.0-REQUIREMENTS.md confirmed: 26 rows show "Pending", 7 show "Complete"; all must become "Complete" |
| DOC-02 | Phase 04 SUMMARY files have requirements-completed fields populated | All 4 SUMMARY files read; YAML frontmatter structure confirmed; requirement mappings derived from SUMMARY content |
| DOC-03 | Legal docs [Launch Date] placeholder replaced with actual launch date | Grep confirms 2 live placeholder instances in legal docs; planning files contain the string only in descriptive/commentary contexts |
</phase_requirements>

---

## Summary

Phase 13 is a pure documentation accuracy pass with no code changes. It addresses three tracking deficiencies left from v1.0 shipping: an outdated traceability table, missing YAML fields in Phase 04 SUMMARY files, and unfilled launch-date placeholders in legal documents.

All three requirements are fully understood from reading the affected files directly. The traceability table in `.planning/milestones/v1.0-REQUIREMENTS.md` has 26 rows still showing "Pending" alongside 7 that were already marked "Complete" (R4.1, R4.2, R7.1, R7.2, R9.1, R9.2, R9.3). Since v1.0 shipped all 33 requirements, every row must become "Complete". The four Phase 04 SUMMARY files exist and have correct YAML frontmatter structure — they simply lack the `requirements-completed` field. The `[Launch Date]` placeholder appears in exactly two live locations: line 3 of `docs/legal/terms-of-service.md` and line 3 of `docs/legal/privacy-policy.md`.

The requirement-to-plan mapping for DOC-02 (a discretion item) is confirmed by reading SUMMARY content. 04-01 built the proxy service and rewired AIService, covering R2.5 and R5.1. 04-02 implemented the full AI Assist panel (Improve/Variables/Tags/Score/Refine tabs), covering R2.1, R2.2, R2.3, R2.4. 04-03 built the Run tab and response management, covering R5.2 and R5.3. 04-00 was prep work (Wave 0 test stubs) with no requirements completed directly.

**Primary recommendation:** Execute in DOC-01 → DOC-02 → DOC-03 order, one commit each. All edits are mechanical find-and-update operations with no judgment calls except for the `[Launch Date]` boundary case in 07-01-PLAN.md (see Open Questions).

---

## Standard Stack

This phase involves no libraries or package dependencies. All work is Markdown and YAML editing.

### Tools Used
| Tool | Purpose |
|------|---------|
| grep / Read | Verify current state before editing |
| Write / Edit | Apply changes to target files |
| grep (post-edit) | Automated verification after each commit |

---

## Architecture Patterns

### YAML Frontmatter Format (DOC-02)

Existing SUMMARY frontmatter uses YAML block style. The `requirements-completed` field follows the established list pattern used by other list fields (`tags`, `dependency_graph.requires`, etc.):

```yaml
requirements-completed: []          # for 04-00 (no requirements completed)
requirements-completed: [R2.5, R5.1]  # for 04-01
requirements-completed: [R2.1, R2.2, R2.3, R2.4]  # for 04-02
requirements-completed: [R5.2, R5.3]  # for 04-03
```

Insert after the `decisions` field and before `metrics` (maintains logical grouping: what was built → what it completed → how it performed).

### Traceability Table Format (DOC-01)

The table in v1.0-REQUIREMENTS.md uses standard Markdown pipe format:

```markdown
| Requirement | Phase | Status |
|-------------|-------|--------|
| R1.1: Canvas UX Edge Cases | Phase 2 | Complete |
```

Only the `Status` column changes. Arrow notation in Phase column (e.g., "Phase 4 → Phase 10") is preserved as-is. The 7 rows already showing "Complete" are not touched.

### Launch Date Replacement (DOC-03)

Simple string substitution: `[Launch Date]` → `2026-04-27`.

The two live instances are at the very top of each legal document (line 3):
- `docs/legal/terms-of-service.md`: `Effective date: [Launch Date]`
- `docs/legal/privacy-policy.md`: `Last updated: [Launch Date]`

---

## Don't Hand-Roll

This phase has no complex problems. All tasks are mechanical edits to existing files.

---

## Common Pitfalls

### Pitfall 1: Over-broad [Launch Date] replacement
**What goes wrong:** Replacing `[Launch Date]` in files where it appears as commentary about the placeholder (e.g., `.planning/MILESTONES.md` line 32: "Legal docs contain [Launch Date] placeholder"), which would corrupt the meaning of those sentences.
**Why it happens:** A naive sed/replace-all hits all occurrences, not just the live ones.
**How to avoid:** Read each file before editing. The live instances are in legal docs at line 3 only. Planning files use the string to describe the problem, not as an actual placeholder requiring a date.
**Warning signs:** If you see `[Launch Date]` in a sentence like "X contains [Launch Date] placeholder", that is commentary — do not replace.

### Pitfall 2: [Launch Date] in 07-01-PLAN.md
**What goes wrong:** Lines 124 and 128 of `.planning/milestones/v1.0-phases/07-app-store-readiness/07-01-PLAN.md` contain `[Launch Date]` as plan instructions written at authoring time (e.g., "Update 'Last updated' date to the current date placeholder '[Launch Date]' (user sets actual date at launch)"). These are historical plan text, not live placeholders.
**How to avoid:** The CONTEXT.md does not list this file as a target. Treat as out of scope unless instructed. The CONTEXT.md lists specific planning files; 07-01-PLAN.md is not among them.
**Warning signs:** The surrounding sentence explains that the user fills the date — these are instructions, not placeholder values in the document itself.

### Pitfall 3: Wrong SUMMARY field placement breaks YAML
**What goes wrong:** Inserting `requirements-completed` in the wrong YAML position causes frontmatter parsing errors.
**How to avoid:** Insert after the `decisions` field and before `metrics`. Verify the triple-dash delimiters (`---`) are intact after editing.
**Warning signs:** The frontmatter `---` block structure is disrupted.

### Pitfall 4: Treating all 33 rows as needing change
**What goes wrong:** Modifying the 7 rows already marked "Complete" (R4.1, R4.2, R7.1, R7.2, R9.1, R9.2, R9.3) is harmless but wasteful and creates unnecessary diff noise.
**How to avoid:** Only update the 26 rows currently showing "Pending". Read the file first to confirm current state.

### Pitfall 5: Backfilling other phase SUMMARYs for DOC-02
**What goes wrong:** While editing Phase 04 SUMMARYs, noticing that other phase SUMMARYs also lack `requirements-completed` and adding the field to them.
**Why it happens:** Scope creep — looks like a simple fix.
**How to avoid:** DOC-02 is explicitly scoped to Phase 04 only. Other phases are not tracked as tech debt for v1.1.

---

## File Inventory

### DOC-01 Target
| File | Path | Change |
|------|------|--------|
| v1.0 archived requirements | `.planning/milestones/v1.0-REQUIREMENTS.md` | Change 26 "Pending" → "Complete" in traceability table |

### DOC-02 Targets
| File | Path | Change |
|------|------|--------|
| Phase 04 Plan 00 SUMMARY | `.planning/milestones/v1.0-phases/04-pro-features-ai-assist-api-runner/04-00-SUMMARY.md` | Add `requirements-completed: []` |
| Phase 04 Plan 01 SUMMARY | `.planning/milestones/v1.0-phases/04-pro-features-ai-assist-api-runner/04-01-SUMMARY.md` | Add `requirements-completed: [R2.5, R5.1]` |
| Phase 04 Plan 02 SUMMARY | `.planning/milestones/v1.0-phases/04-pro-features-ai-assist-api-runner/04-02-SUMMARY.md` | Add `requirements-completed: [R2.1, R2.2, R2.3, R2.4]` |
| Phase 04 Plan 03 SUMMARY | `.planning/milestones/v1.0-phases/04-pro-features-ai-assist-api-runner/04-03-SUMMARY.md` | Add `requirements-completed: [R5.2, R5.3]` |

### DOC-03 Targets (live placeholder instances only)
| File | Path | Line | Change |
|------|------|------|--------|
| Terms of Service | `docs/legal/terms-of-service.md` | 3 | `[Launch Date]` → `2026-04-27` |
| Privacy Policy | `docs/legal/privacy-policy.md` | 3 | `[Launch Date]` → `2026-04-27` |

### DOC-03 Non-targets (commentary, not live placeholders)
| File | Why Not a Target |
|------|-----------------|
| `.planning/MILESTONES.md` | Describes the tech debt item — "Legal docs contain [Launch Date] placeholder" |
| `.planning/PROJECT.md` | Lists target fixes — "Legal docs [Launch Date] placeholder" |
| `.planning/REQUIREMENTS.md` | Defines DOC-03 requirement — mentions string as problem description |
| `.planning/ROADMAP.md` | States success criteria — mentions string as what to check for |
| `.planning/milestones/v1.0-phases/07-app-store-readiness/07-VERIFICATION.md` | Documents the placeholder as an expected/known issue at the time |
| `.planning/milestones/v1.0-phases/07-app-store-readiness/07-01-PLAN.md` | Historical plan instructions telling the user to fill the date — not a live date field |
| `.planning/milestones/v1.0-MILESTONE-AUDIT.md` | Audit record documenting the known debt |
| `.planning/phases/13-documentation-legal/13-CONTEXT.md` | This phase's own context document |

---

## Requirement-to-Plan Mapping (Verified from SUMMARY Content)

This mapping was Claude's discretion item — confirmed by reading each SUMMARY:

**04-01 (Cloudflare Worker Proxy & AIService Rewiring):**
- R2.5 (Proxy Service Integration): Built the proxy worker and rewired AIService to route through it
- R5.1 (Prompt Execution): `buildStreamRequest` routes execution calls through proxy; streaming infrastructure established

**04-02 (AI Assist Panel — Streaming & Full Tab Implementation):**
- R2.1 (AI Prompt Improvement): Improve tab with streaming DiffView + Accept/Reject
- R2.2 (AI Variable Suggestion): Variables tab with per-suggestion accept/reject
- R2.3 (AI Auto-Tagging): Tags tab with on-demand "Suggest Tags" button
- R2.4 (AI Quality Scoring): Score tab with four-axis scores + actionable tips

**04-03 (API Runner — Run Tab, History & Privacy Manifest):**
- R5.2 (Response Management): ResponsePanel StreamEvent consumption, `persistRun()` with token counts, RunHistoryView with ratings and delete
- R5.3 (Refinement Loop): "Run Again" button in RunHistoryView with `onRunAgain` callback, side-by-side prompt editor and response view in Run tab

---

## Traceability Table Status (Confirmed)

Rows currently "Complete" (7) — do not change:
- R4.1, R4.2 (Analytics — Phase 5 → Phase 12)
- R7.1, R7.2 (App Store Readiness / Privacy — Phase 1)
- R9.1, R9.2, R9.3 (Import/Export — Phase 6 → Phase 11)

Rows currently "Pending" (26) — all must become "Complete":
R1.1, R1.2, R1.3, R1.4, R2.1, R2.2, R2.3, R2.4, R2.5, R3.1, R3.2, R3.3, R4.3, R5.1, R5.2, R5.3, R6.1, R6.2, R6.3, R6.4, R7.3, R7.4, R8.1, R8.2, R8.3, R8.4

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | None — documentation-only phase; no code compiled or executed |
| Config file | N/A |
| Quick run command | `grep -r "Pending" .planning/milestones/v1.0-REQUIREMENTS.md` (should return empty) |
| Full suite command | See Phase Gate below |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DOC-01 | No "Pending" rows remain in v1.0 traceability table | smoke (grep) | `grep "Pending" .planning/milestones/v1.0-REQUIREMENTS.md \|\| echo PASS` | ✅ file exists, grep run post-edit |
| DOC-02 | `requirements-completed` present in all 4 Phase 04 SUMMARYs | smoke (grep) | `grep -l "requirements-completed" .planning/milestones/v1.0-phases/04-pro-features-ai-assist-api-runner/*-SUMMARY.md \| wc -l` (expect 4) | ✅ files exist |
| DOC-03 | No `[Launch Date]` placeholder remains in repo | smoke (grep) | `grep -r "\[Launch Date\]" docs/legal/ \|\| echo PASS` | ✅ files exist |

### Sampling Rate
- **Per task commit:** Run the grep check for that DOC requirement before committing
- **Per wave merge:** N/A — single wave
- **Phase gate:** All three grep checks pass before marking phase complete

### Wave 0 Gaps
None — existing test infrastructure covers all phase requirements (grep-based smoke checks, no test files needed)

---

## Open Questions

1. **07-01-PLAN.md lines 124/128**
   - What we know: These lines contain `[Launch Date]` as plan-authoring instructions ("user sets actual date at launch"), not as live date values in a delivered document
   - What's unclear: The CONTEXT.md does not explicitly list this file as a DOC-03 target, but the grep result surfaces it
   - Recommendation: Do not replace. These are historical plan instructions in an archived plan file. The legal docs (the delivered artifacts) are the correct targets. If in doubt, leave unchanged and note in commit message.

2. **Minor formatting issues during editing**
   - What we know: CONTEXT.md grants discretion to fix minor formatting issues noticed while editing targeted files
   - What's unclear: What counts as "minor" (e.g., trailing whitespace vs. structural changes)
   - Recommendation: Fix only whitespace/punctuation issues directly adjacent to the lines being edited. Do not restructure sections.

---

## Sources

### Primary (HIGH confidence)
- Direct file reads of all target files — current state confirmed by reading, not assumed
- `.planning/milestones/v1.0-REQUIREMENTS.md` — traceability table row-by-row inspection
- `.planning/milestones/v1.0-phases/04-pro-features-ai-assist-api-runner/04-{00,01,02,03}-SUMMARY.md` — requirement mappings derived from SUMMARY descriptions
- `docs/legal/terms-of-service.md`, `docs/legal/privacy-policy.md` — placeholder locations confirmed
- grep output across full repo — all `[Launch Date]` occurrences catalogued

### Secondary (MEDIUM confidence)
- None required — all findings from direct file inspection

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- DOC-01 changes: HIGH — traceability table read directly; 26 Pending rows confirmed; format understood
- DOC-02 changes: HIGH — all 4 SUMMARY files read; YAML structure confirmed; requirement mappings verified from content
- DOC-03 changes: HIGH — grep confirms exactly 2 live placeholder instances; non-target files confirmed as commentary

**Research date:** 2026-04-27
**Valid until:** No expiry — all findings are from direct file inspection of static files
