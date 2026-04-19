---
name: guitar-library
description: Maintain the book corner of the guitar Materials DB that backs the Notion Music workspace — Calibre-sourced PDFs catalogued in Notion, preprocessed (OCR + size/page splits) to fit Claude Project caps, linked to exercises and usage guides. Use when onboarding new books, processing scanned PDFs, splitting oversized files, building/refreshing the book catalog, or syncing the system doc. Claude Code CLI only (filesystem/calibre/notion MCP required). Session coaching + logging + non-book materials (courses, videos) live in the Music Project's Custom Instructions, not here.
---

# Guitar library — maintenance

Keeps the `guitar` / `sheet-music` corner of the Calibre library at
`~/OneDrive/Documents/books/` indexed, readable, and within Claude
Project file caps, and mirrors that state into the Notion **Materials
DB** (where `Type=Book`).

**Scope:** book preprocessing + catalog only. Non-book Materials rows
(video courses, lesson series, individual videos, websites) are
user-curated in Notion directly — this skill ignores them. Coaching,
session structure, and Practice Log writes live in the Music Project's
Custom Instructions (Claude Desktop + mobile). Don't duplicate them
here.

**Surface:** Claude Code CLI on the laptop. Requires `filesystem` and
`notion` MCP servers. Calibre is accessed via the `calibredb` CLI
(`C:\Program Files\Calibre2\calibredb.exe` on Windows, `calibredb` on
Linux — installed by dotfiles winget/apt scripts). Mobile and claude.ai
web cannot run any workflow here.

## Hard caps (design constraints)

Claude Project file limits Claude must never exceed when producing
uploadable artifacts:

- **≤ 30 MB per file** (enforced).
- **≤ 100 pages per file** (visual analysis cap — guitar notation needs
  vision, so this is a hard cap, not a soft one).
- Unlimited file count per Project.

Anything in the library over either cap is a **split candidate**.

## Materials DB — the state machine

All workflows are driven by state columns on the Notion **Materials DB**
(child of Guitar Mastery project page). Resolve the DB at runtime via
`notion-search`; don't hardcode IDs.

**This skill only operates on rows where `Type=Book`.** Non-book rows
(`Video course`, `Lesson series`, `Video (single)`, `Website`, `Other`)
are user-curated; every query and write below is scoped to
`Type=Book`.

Shared columns (all Types):

| Column | Meaning |
|---|---|
| `Title`, `Authors` / `Instructor` | Name + creator. |
| `Type` | `Book`, `Video course`, `Lesson series`, `Video (single)`, `Website`, `Other`. |
| `URL` | For non-book types (or publisher page for books). |
| `Primary tag` | `guitar`, `sheet-music` (for books); analogous tags for other types. |
| `Topics` (multi-select) | Shared vocabulary across Types — drives cross-media recommendations. |
| `Skill level` | `beginner`, `intermediate`, `advanced`, `mixed`. |
| `Summary` | 2–3 sentences. Filled by **Index book** for Type=Book. |
| `Progress` | Free text ("Ch. 2, ~50%"). User/coach maintained for non-book types. |
| `Usage guides` | Relation → Guides DB. |
| `Exercises` | Relation → Exercises DB. |

Book-only columns (used only when `Type=Book`):

| Column | Values | Meaning |
|---|---|---|
| `Calibre ID`, `File path`, `Pages`, `Size MB` | — | Mirrored from Calibre. `File path` is the PDF in the library; for split books, one row per part with `File path` pointing at the part. |
| `Text layer` | `Unknown`, `Native`, `OCRed`, `Scanned` | `Unknown` = never triaged. `Native` = original had a text layer. `OCRed` = we added one via ocrmypdf. `Scanned` = needs OCR (image-only). |
| `Cap status` | `Unknown`, `Under caps`, `Over size`, `Over pages`, `Split` | `Under caps` = ≤30 MB and ≤100 pages. `Split` = this row is a part of a parent book. |
| `Parent book` | relation → self | Set on split-part rows; points at the pre-split canonical row. |
| `Indexed` | checkbox | True once summary/TOC/exercises extracted. |
| `Last indexed` | date | Last successful index pass. |
| `TOC` | — | Chapter/section outline. Filled by **Index book**. |

Every workflow below reads this state, operates only on rows that need
work, and writes state back. Safe to re-run; idempotent.

## Workflow: Discover

Purpose: reconcile Calibre with the Materials DB (`Type=Book` rows
only). Creates stub rows for new books and marks rows stale when the
underlying file changed.

1. `calibredb list --for-machine --fields id,title,authors,formats,tags \
   --search "tag:guitar OR tag:sheet-music"` → JSON list of books.
2. For each Calibre row, find Materials DB row where `Type=Book` AND
   `Calibre ID` matches.
3. Missing → create stub row with `Type=Book`, `Text layer=Unknown`,
   `Cap status=Unknown`, `Indexed=false`, `File path` = PDF path,
   `Pages` and `Size MB` from `filesystem` (via `pdftk dump_data` /
   stat).
4. Present but `File path` / `Size MB` / `Pages` changed → reset
   `Text layer=Unknown`, `Cap status=Unknown`, `Indexed=false` so
   downstream workflows re-triage. Leave `Summary`/`TOC` in place —
   they get overwritten on re-index.
5. Calibre row gone → set a `Removed` marker (don't delete the row; it
   may carry session history references).

Never touch rows where `Type ≠ Book`.

Report: `N new, M stale, K removed`.

## Workflow: OCR triage

Purpose: make scanned PDFs text-searchable so indexing and in-session
reading work. Runs on the **source** file (before splitting) to amortise
OCR cost across parts.

Scope: rows where `Type=Book` AND `Text layer ∈ {Unknown, Scanned}` AND
`Cap status ≠ Split` (never OCR a split-part; the parent carried or will
carry the OCR).

Per row:

1. Detect text layer: `pdftotext -l 10 <path> -` (first 10 pages). Empty
   or near-empty output → `Scanned`. Non-trivial output → `Native`.
2. If `Native` → set `Text layer=Native`, done.
3. If `Scanned`:
   ```bash
   uvx ocrmypdf --skip-text --optimize 1 --jobs 4 \
       "<path>" "<path>.ocr.tmp.pdf"
   ```
   On success: replace original, set `Text layer=OCRed`, update
   `Size MB`. On failure: leave `Text layer=Scanned`, log reason in
   `Notes`, move on.

Precondition for **Split book** and **Index book**: `Text layer ∈
{Native, OCRed}`. Splitting before OCR would force N OCR passes (one per
part) instead of one on the source.

## Workflow: Split book

Purpose: enforce the 30 MB / 100 page caps by splitting oversized PDFs
into parts, each independently under both caps.

Scope: rows where `Type=Book` AND `Cap status ∈ {Unknown, Over size,
Over pages}` AND `Text layer ∈ {Native, OCRed}` AND row is not itself a
`Split` part.

Per row:

1. Measure: size = `stat`, pages = `pdftk dump_data | grep NumberOfPages`.
2. Both caps met → `Cap status=Under caps`. Done.
3. One or both violated → split. Strategy:
   - **Page-based split** into contiguous ranges of ≤100 pages, preferring
     chapter/part boundaries from the PDF outline (`pdftk dump_data` or
     `qpdf --json` for the outline). If a resulting part is still > 30
     MB, sub-split that part in half by page count (recurse).
   - **Attachment strip first** if the source has embedded attachments
     (MP3 audio, zips — common in guitar PDFs): `qpdf --remove-attachments`
     to a working copy before splitting. Attachments bloat every part
     otherwise.
4. Write parts to `<original_dir>/<stem>.part-NN.pdf`, NN zero-padded.
5. Update state:
   - Parent row → `Cap status=Over size`/`Over pages` stays for audit,
     plus checkbox `Superseded by parts`.
   - One new row per part with `Cap status=Split`, `Parent book` →
     parent, `Text layer` inherited (that's why OCR runs first), `Pages`
     and `Size MB` from the part, `Indexed=false`.
6. Verify each part opens (`qpdf --check`) and is under both caps. If
   any part fails → roll back: delete parts, mark parent `Cap
   status=Over size` (or `Over pages`), leave a `Split failed: <reason>`
   note.

## Workflow: Index book

Purpose: fill summary / TOC / skill level / topics / exercise relations
on rows that are upload-ready.

Scope: rows where `Type=Book` AND `Indexed=false` AND `Cap status ∈
{Under caps, Split}` AND `Text layer ∈ {Native, OCRed}`.

Parallelism: one subagent per row, 3–5 concurrent (`general-purpose`
agent type). Fresh 200k context per book avoids chat-window blowup.

Per subagent:

1. Read the part / whole PDF via `filesystem` MCP.
2. Extract:
   - **Summary** — 2–3 sentences.
   - **Skill level** — beginner / intermediate / advanced / mixed.
   - **Topics** (multi-select) — e.g. `slurs`, `right-hand arpeggios`,
     `pentatonics`, `sight reading`, `repertoire: classical`, etc.
     Use the existing `Topics` vocabulary shared across all Types —
     don't invent parallel terms.
   - **TOC** — chapter/section titles with page refs.
   - **Exercises** — named exercises with page refs, technique focus,
     difficulty.
3. Update Materials row properties + create Exercises DB rows linked
   via `Exercises` relation.
4. Set `Indexed=true`, `Last indexed=today`. Leave `Usage guides`
   untouched — those are user-curated.

## Workflow: Sync system doc

Purpose: keep the Notion "Guitar Tutor System — How this works" child
page (under Guitar Mastery) in sync with the markdown source of truth
at `home/dot_claude/skills/guitar-library/system-architecture-and-updating.md`.

1. Resolve "Guitar Tutor System" child page under Guitar Mastery via
   `notion-search`. Create if missing.
2. Read current page content via `notion-fetch`.
3. Read the markdown source.
4. If different → `notion-update-page` with `update_content` replacing
   the whole body (simplest correct approach; page is a single
   Claude-maintained document).

Run after edits to `system-architecture-and-updating.md` land in
dotfiles and `chezmoi apply` has run.

## Canonical run order on a fresh machine

```
Discover  →  OCR triage  →  Split book  →  Index book  →  Sync system doc
```

Re-runs are safe at any step because each workflow only touches rows
whose state says they need work.

## Notion gotchas for this skill

See the Music Project Custom Instructions for the full Notion MCP
operational notes (property keys, multi-select JSON-array format,
data-source URL conventions). Specific to this skill:

- Materials DB parent: use the DB's `data_source_id`, same pattern as
  Practice Log.
- `Topics`, `Text layer`, `Cap status` multi-selects: pass as JSON array
  strings (`'["slurs", "right-hand arpeggios"]'`).
- Adding a new `Topics` / `Text layer` / `Cap status` / `Type` value
  requires `notion-update-data-source` with ALTER COLUMN before creating
  rows that use it.
- Never edit Practice Log schema from this skill. This skill only reads
  Practice Log (and only via the Project Custom Instructions' coaching
  workflow — not here).
- Never modify rows where `Type ≠ Book`. Those are user-curated.
