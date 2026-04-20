---
name: guitar-tutor
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

**Calibre GUI must be closed** before any workflow that writes to the
Calibre library (Format normalize, OCR triage, Split book, tag fixes).
Reads (`calibredb list`, direct `metadata.db` queries) work concurrently.
Check with `Get-Process calibre*`; ask the user to close it before
proceeding with writes.

## Querying Calibre — patterns that work

`calibredb list --for-machine` returns a fixed shape and can't join
across tables (formats, tags, languages, custom columns). For richer
queries, hit `metadata.db` directly. **Don't** assume a system Python
or `sqlite3` CLI exists on Windows — neither does. Use Calibre's
bundled Python via `calibre-debug -e <script.py>`:

```bash
cat > "$LOCALAPPDATA/Temp/q.py" << 'EOF'
import sqlite3
conn = sqlite3.connect(r"C:/Users/trist/OneDrive/Documents/books/metadata.db")
cur = conn.cursor()
cur.execute("""
  SELECT b.id, b.title, a.name, d.format, d.uncompressed_size, t.name
  FROM books b
  JOIN books_authors_link bal ON bal.book = b.id
  JOIN authors a ON a.id = bal.author
  JOIN data d ON d.book = b.id
  LEFT JOIN books_tags_link btl ON btl.book = b.id
  LEFT JOIN tags t ON t.id = btl.tag
  WHERE t.name IN ('guitar', 'sheet-music')
""")
for r in cur.fetchall(): print(r)
EOF
& 'C:\Program Files\Calibre2\calibre-debug.exe' -e "$LOCALAPPDATA/Temp/q.py"
```

Key tables: `books`, `data` (formats, with `format` and
`uncompressed_size`), `books_authors_link` ↔ `authors`,
`books_tags_link` ↔ `tags`, `books_publishers_link` ↔ `publishers`,
`books_languages_link` ↔ `languages`, `comments` (book.id ↔
comments.book → text). The `data` table has one row per format per
book; `format` is uppercase (`PDF`, `EPUB`, `ZIP`).

`calibredb` write commands when GUI is closed:

```bash
calibredb add_format <book_id> <path>           # add/replace format
calibredb remove_format <book_id> <FORMAT>      # remove format + delete file
calibredb set_metadata <book_id> --field tags:"guitar,sheet-music"
calibredb add <path> --title "T" --authors "A" --tags "sheet-music"
```

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
| `Primary tag` (multi-select) | `guitar`, `sheet-music` (for books); a row may carry both — e.g. Brouwer's etudes are pedagogy *and* performance scores. |
| `Topics` (multi-select) | Shared vocabulary across Types — drives cross-media recommendations. |
| `Skill level` | `beginner`, `intermediate`, `advanced`, `mixed`. |
| `Summary` | 2–3 sentences. Filled by **Index book** for Type=Book. |
| `Progress` | Free text ("Ch. 2, ~50%"). User/coach maintained for non-book types. |
| `Usage guides` | Relation → Guides DB. |
| `Exercises` | Relation → Exercises DB. |

Book-only columns (used only when `Type=Book`):

| Column | Values | Meaning |
|---|---|---|
| `Calibre ID`, `File path`, `Pages`, `Size MB` | — | Mirrored from Calibre. `File path` always points to the **PDF** Claude works with (post-normalize). For split books, one row per part. |
| `Text layer` | `Unknown`, `Native`, `OCRed`, `Scanned` | `Unknown` = never triaged. `Native` = original had a text layer. `OCRed` = we added one via ocrmypdf. `Scanned` = needs OCR (image-only). |
| `Cap status` | `Unknown`, `Under caps`, `Over size`, `Over pages`, `Split` | `Under caps` = ≤30 MB and ≤100 pages. `Split` = either (a) this row was split into parts, OR (b) this row is one of those parts. Distinguish via `Parent book`: empty on parents, set on parts. |
| `Parent book` | relation → self | Set on split-part rows; points at the pre-split canonical row. Empty on the parent itself. |
| `Indexed` | checkbox | True once summary/TOC/exercises extracted. |
| `Last indexed` | date | Last successful index pass. |
| `TOC` | — | Chapter/section outline. Filled by **Index book**. |
| `Removed` | checkbox | Set when the Calibre row disappears. The Materials row is preserved (may carry session-history references) but workflows skip it. |

Every workflow below reads this state, operates only on rows that need
work, and writes state back. Safe to re-run; idempotent.

## Workflow: Discover

Purpose: reconcile Calibre with the Materials DB (`Type=Book` rows
only). Creates stub rows for new books, marks rows stale when the
underlying file changed, marks rows removed when the Calibre book is
gone.

Query Calibre directly via the `metadata.db` SQLite pattern documented
above — `calibredb list` is too lossy (doesn't expose per-format size,
can't filter by format). Pull `id, title, author, format, size, tags`
all in one query.

Per Calibre row:

1. Pick the **canonical file** for the row in this priority order:
   `PDF` > `EPUB` > `ZIP` > anything else. `File path`, `Pages`, and
   `Size MB` mirror the canonical file. (If the canonical is not yet
   PDF, **Format normalize** will replace it on its next pass and then
   re-trigger this row's Discover update.)
2. Find the Materials DB row where `Type=Book` AND `Calibre ID`
   matches. Resolve the Materials DB at runtime via `notion-search`;
   don't hardcode IDs.
3. Missing → create stub row: `Type=Book`, `Text layer=Unknown`,
   `Cap status=Unknown`, `Indexed=false`, `Primary tag` = Calibre tags
   (multi-select; pass `["guitar", "sheet-music"]` etc.), plus the
   canonical-file fields above. For PDFs, also fill `Pages` via
   `pdftk dump_data | grep NumberOfPages`. For non-PDFs, leave `Pages`
   null (Format normalize will fill it).
4. Present but `File path` / `Size MB` / `Pages` changed → reset
   `Text layer=Unknown`, `Cap status=Unknown`, `Indexed=false` so
   downstream workflows re-triage. Leave `Summary`/`TOC` in place —
   they get overwritten on re-index.
5. Calibre row gone → set `Removed=true` (don't delete the Materials
   row; it may carry session history references). All workflows skip
   `Removed=true` rows.

Never touch rows where `Type ≠ Book`.

Report: `N new, M stale, K removed`.

## Workflow: Format normalize

Purpose: every book Claude works with must exist as a PDF in Calibre.
Sheet-music ZIPs and reading-format EPUBs need their PDF representation
materialised first — before OCR triage and Split book run.

Runs after **Discover** and before **OCR triage**. Calibre GUI must be
closed.

### ZIP → PDF (sheet-music archives)

Scope: rows where the underlying Calibre book has a `ZIP` format and no
`PDF` format yet.

Sheet-music ZIPs (Kapuściński, von Ziegler, etc.) bundle MuseScore
sources plus rendered PDFs — sometimes one PDF, sometimes several
arrangements (acoustic / classical / 12-string / part 1 / part 2).

Per ZIP:

1. Open the ZIP; list `*.pdf` entries.
2. **One PDF inside** → extract → `calibredb add_format <id> <pdf>` →
   `calibredb remove_format <id> ZIP`. Done.
3. **Multiple PDFs inside**:
   - Match the **primary PDF** to the existing Calibre title using
     arrangement keywords (`acoustic`, `classical`, `12-string`,
     `7-string`, `1st guitar`, `guitar 1`, etc.). Highest-scoring PDF
     wins; ties → alphabetical.
   - `add_format` the primary onto the existing entry.
   - For each remaining PDF: `calibredb add <pdf> --title
     "<original title> — <arrangement>" --authors "<same author>"
     --tags "sheet-music"` to create a new Calibre book per
     arrangement. Title comes from the PDF filename (cleaned up) so
     each entry is self-describing.
   - `remove_format <original_id> ZIP`.

The ZIP format is always removed — it's a redundant container once
PDFs are first-class.

### EPUB → PDF (reading-format books)

Scope: rows where the Calibre book has an `EPUB` format and no `PDF`
format. The EPUB stays for user reading; the PDF is what Claude works
with (the workflows below all assume PDF).

Per EPUB:

1. Convert: `ebook-convert "<epub>" "<tmpdir>/<stem>.pdf"` (Calibre's
   converter handles images, layout, embedded fonts).
2. **Verify** programmatically:
   - PDF opens (`qpdf --check`).
   - Pages > 0 (`pdftk dump_data | grep NumberOfPages`).
   - Size > 100 KB (smaller usually means conversion produced an
     empty/broken file).
   - First-page text extractable (`pdftotext -l 1`); empty text on a
     converted EPUB usually means the source was image-only and the
     output PDF is image-only too — flag for OCR triage downstream.
3. On all checks pass: `calibredb add_format <id> <pdf>` (PDF format
   added alongside EPUB).
4. On any check fail: leave EPUB alone, log to a `Conversion failed:
   <reason>` note in the Materials row, skip the row in OCR/Split/Index.
5. **Spot-check prompt**: image-heavy notation EPUBs (anything with
   significant musical engraving) should be opened in Calibre's viewer
   by the user before relying on the converted PDF. Surface a list of
   converted books at the end of the run for human review; user can
   re-trigger conversion with different `ebook-convert` flags
   (`--pdf-default-font-size`, `--pdf-page-margin-*`, etc.) if any are
   unacceptable.

After Format normalize completes, every `Type=Book` row in the
Materials DB has a PDF in Calibre. OCR triage and Split book operate
on those PDFs.

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
Over pages}` AND `Text layer ∈ {Native, OCRed}` AND `Parent book` is
empty (never re-split a part, and never re-split a parent that already
has `Cap status=Split`).

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
   - Parent row → set `Cap status=Split`. (Scope filters on
     `Cap status ∈ {Unknown, Over size, Over pages}`, so `Split`
     parents are never re-processed. `Parent book` remains empty on
     the parent, distinguishing it from its parts.)
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
Subagents use only the `Read` tool (filesystem MCP) — no Bash, no
Notion. All Notion writes go through the main session.

Per subagent:

1. Read the part / whole PDF via `filesystem` MCP.
2. Extract:
   - **Summary** — 2–3 sentences.
   - **Skill level** — beginner / intermediate / advanced / mixed.
   - **Topics** (multi-select) — use ONLY the allowed vocabulary (see
     below). Never invent new terms; normalize anything outside the
     list before writing.
   - **TOC** — chapter/section titles with page refs.
   - **Exercises** — named exercises with page refs, technique focus,
     difficulty.
3. Update Materials row properties + create Exercises DB rows linked
   via `Exercises` relation.
4. Set `Indexed=true`, `Last indexed=today`. Leave `Usage guides`
   untouched — those are user-curated.

### Allowed Topics vocabulary (35 terms)

`slurs`, `right-hand arpeggios`, `scales`, `sight reading`,
`repertoire: classical`, `music theory`, `pentatonics`, `legato`,
`fingerstyle`, `alternate picking`, `repertoire: folk`,
`repertoire: original`, `repertoire: Celtic`, `repertoire: Baroque`,
`repertoire: Renaissance`, `repertoire: pop/rock`,
`repertoire: video game`, `Christmas music`, `fingerpicking`,
`arpeggios`, `hammer-ons/pull-offs`, `barre chords`, `chord melody`,
`ornaments`, `vibrato`, `position work`, `solo guitar`, `duet`,
`arrangement`, `etude`, `technique study`, `tremolo`, `flamenco`,
`improvisation`, `ear training`

Known normalization fixes: "right-hand technique" → `technique study`,
"hammer-ons/pull-ons" → `hammer-ons/pull-offs`, "articulation study"
→ drop it.

### Fallback: "Prompt is too long" (PDF >~12 MB)

When a subagent returns "Prompt is too long" or asks for Bash, run
this in the main session instead:

```bash
pdftotext -l 20 "<path>" - 2>&1 | head -80
```

Use the extracted text plus the book title/author/context to construct
metadata manually and write directly to Notion.

### Shortcut: small single-piece sheet music scores

For tiny scores (<1 MB, single guitar arrangements) the metadata is
fully inferrable from title, author, and arrangement keywords — no
subagent needed. Write directly:

- **Summary**: "Guitar tablature/notation for [title] by [composer],
  arranged by [arranger] for [instrument]. [Brief style note]."
- **Skill level**: `intermediate` (default for arranged scores).
- **Topics**: `arrangement` + repertoire tag (Celtic, folk, video game,
  Christmas, etc.) + `fingerstyle` + `solo guitar` or `duet` based on
  whether it's a numbered ensemble part.
- **TOC**: "[Title] – [Instrument]"

### Back-matter-only parts

When a split part contains only reference appendices or back cover
(≤4 pages), write a minimal entry noting it's back matter rather than
running a subagent:

- **Summary**: "Part N contains only reference appendices [describe].
  No instructional content; this is back matter from the split."
- Inherit `Skill level` and `Topics` from the parent.

## Workflow: Sync system doc

Purpose: keep the Notion "Guitar Tutor System — How this works" child
page (under Guitar Mastery) in sync with the markdown source of truth
at `home/dot_claude/skills/guitar-tutor/system-architecture-and-updating.md`.

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
Discover  →  Format normalize  →  OCR triage  →  Split book  →  Index book  →  Sync system doc
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
