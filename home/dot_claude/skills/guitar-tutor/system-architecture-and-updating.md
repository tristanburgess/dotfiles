# Guitar Tutor System — How this works

Source of truth for the Notion **Guitar Tutor System — How this works**
child page under the Guitar Mastery project. Lives in the dotfiles
repo at `home/dot_claude/skills/guitar-tutor/`; synced to Notion via
the `guitar-tutor` skill's **Sync system doc** workflow.

Edit this file, `chezmoi apply`, then run the sync workflow to push
updates into Notion. Never edit the Notion page directly — your edits
will be overwritten on next sync.

## What the system does

Lets Claude act as guitar practice coach, music theory tutor, session
logger, and library curator across three surfaces (laptop desktop,
Claude Code CLI, mobile) with a single Notion workspace as source of
truth.

## Architecture at a glance

```
┌─────────────────────────────────────────────────────────┐
│                  Notion — Guitar Mastery                 │
│                                                          │
│    Practice Log    Materials DB    Exercises    Guides   │
│       (UB)         (books +        (page refs,  (usage)  │
│                     courses +       relations)            │
│                     videos +                             │
│                     sites)                               │
└───────────────┬─────────────────────────────────────────┘
                │ notion MCP (laptop) / Notion connector (mobile)
   ┌────────────┴────────────────┐
   │                             │
┌──▼──────────────────┐   ┌──────▼──────────────────┐
│ Laptop              │   │ Mobile                   │
│ Claude Desktop      │   │ Claude mobile app        │
│ + MCP:              │   │ + Project files          │
│   notion            │   │ + Notion connector       │
│   filesystem        │   │   (read/write DBs)       │
│ + Project files     │   │ (no MCP, no skills,      │
│ + Claude Code CLI   │   │  no filesystem)          │
│   with guitar-      │   │                          │
│   library skill     │   │                          │
└───┬─────────────────┘   └──────────────────────────┘
    │ filesystem MCP + calibredb CLI (laptop only)
┌───▼───────────────────────────┐
│ Calibre library (OneDrive)     │
│ ~/OneDrive/Documents/books/    │
│ metadata.db + PDFs             │
└────────────────────────────────┘
```

## Per-surface capability table

| Surface | Projects | MCP | Cloud connectors | Skills | Can open PDFs | Can preprocess library |
|---|---|---|---|---|---|---|
| Claude Desktop (laptop) | yes | notion, filesystem | yes | no | yes (via Project files + filesystem MCP) | no (use Claude Code) |
| Claude Code CLI (laptop) | no | notion, filesystem | yes | yes (`guitar-tutor`) | yes (via filesystem) | yes (calibredb CLI) |
| Claude mobile app | yes | none | yes (notion) | no | Project files only, no arbitrary filesystem | no |
| claude.ai web | yes | none | yes (notion) | no | Project files only | no |

## Notion databases under Guitar Mastery

All four DBs sit as children of the Guitar Mastery project page. Resolve
IDs at runtime via `notion-search` — don't hardcode in prompts.

### Practice Log (pre-existing, part of Ultimate Brain)

Unchanged. Claude writes session entries here. Schema:
`Session` (title), `Instrument` (single-select), `Mood` (8 values),
`Date`, `Duration`, `Focus Area` (multi-select JSON array),
`Resource` (multi-select JSON array — names resolve to Materials rows
on read), body content with all-caps section labels.

### Materials DB (new)

Unified catalog of every learning resource: books, video courses,
lesson series, individual videos, websites.

Shared columns: `Title`, `Authors/Instructor`, `Type`, `URL`,
`Primary tag`, `Topics` (multi-select), `Skill level`, `Summary`,
`Progress` (text), `Usage guides` (relation → Guides),
`Exercises` (relation → Exercises).

Book-only columns (`Type=Book`): `Calibre ID`, `File path`, `Pages`,
`Size MB`, `Text layer` (Unknown/Native/OCRed/Scanned),
`Cap status` (Unknown/Under caps/Over size/Over pages/Split),
`Parent book` (self-relation for split parts), `Indexed` (checkbox),
`Last indexed` (date), `TOC`.

Book rows are fully maintained by the `guitar-tutor` skill.
Non-book rows are user-curated; Claude updates `Progress` on them
during coaching sessions when the user reports progress.

### Exercises DB (new)

Named exercises from indexed books with page refs, technique focus,
difficulty. Relation → Materials DB. Populated by the `guitar-tutor`
skill's **Index book** workflow; user can add manually.

### Guides DB (new)

Usage guides and "how to use this book / course" notes. Each row has
an `Applies to` relation back to Materials rows. Three existing
guideline notes (Shearer Form Checks, How to Use Pumping Nylon,
Progressing Through 20 Practice Routines) migrated into rows here,
each with `Applies to` pointing at their source book rows. User
creates new rows when a pattern emerges worth capturing.

## Where each capability lives

| Capability | Where defined | Surface |
|---|---|---|
| Practice coaching prompt | Music Project Custom Instructions | Desktop, mobile, web |
| Session logging | Music Project Custom Instructions | Desktop, mobile, web |
| Notion MCP operational gotchas | Music Project Custom Instructions | Desktop (mobile uses cloud connector, no gotchas apply) |
| Book preprocessing (OCR, split) | `guitar-tutor` skill | Claude Code CLI |
| Book indexing → Materials/Exercises | `guitar-tutor` skill | Claude Code CLI |
| Sync this doc → Notion | `guitar-tutor` skill's Sync workflow | Claude Code CLI |
| Non-book row creation/progress | User in Notion + Claude during coaching | Any |

## Update loop — how to change the system

### Editing coaching behaviour

1. Edit `home/dot_claude/skills/guitar-tutor/project-instructions.md`
   in the dotfiles repo.
2. `chezmoi apply` (no-op for this file — it's a paste target, not
   deployed).
3. Copy the file's body into Claude Desktop → Music Project →
   Custom Instructions. Save.

The paste is manual because Anthropic exposes no API for Project
Custom Instructions.

### Editing library-maintenance behaviour

1. Edit `home/dot_claude/skills/guitar-tutor/SKILL.md` in the
   dotfiles repo.
2. `chezmoi apply` — deploys to `~/.claude/skills/guitar-tutor/
   SKILL.md`.
3. Restart Claude Code CLI (or start a new session). Changes active.

### Editing this architecture doc

1. Edit `home/dot_claude/skills/guitar-tutor/
   system-architecture-and-updating.md`.
2. `chezmoi apply`.
3. In Claude Code CLI, run the `guitar-tutor` skill's
   **Sync system doc** workflow → pushes content into the Notion
   page you're reading right now.

### Adding or changing installs (MCP servers, OCR tools, etc.)

All installs are in `home/.chezmoiscripts/`:

- `run_onchange_before_01-apt-packages.sh.tmpl` — Linux/WSL apt
  packages (tesseract-ocr, ghostscript, qpdf, etc.).
- `run_after_00-winget-packages.ps1.tmpl` — Windows winget packages
  (calibre, tesseract-ocr, QPDF, etc.).
- `run_onchange_after_10-claude-desktop-mcp.sh.tmpl` — merges the
  `filesystem` MCP server into `claude_desktop_config.json`
  (merge, not overwrite — existing servers like `notion` are preserved).
  Calibre is accessed via `calibredb` CLI, not MCP.
- `home/dot_config/mise/config.toml` — cross-platform tool versions
  (uv, node, bun, jq, etc.).

Edit, `chezmoi apply`, scripts re-run when their content changes.

### Adding a new DB or schema change under Guitar Mastery

Always precede with a Notion backup:

1. Full workspace export: Notion UI → Settings → Export content →
   Everything → Markdown & CSV → save to
   `~/OneDrive/Documents/notion-backups/ub-pre-<change>-<date>.zip`.
2. Scripted DB row dump of anything you're about to modify.
3. Test the change on a sandbox page first when touching Ultimate
   Brain's built-in DBs (Projects, Notes, Tasks).

Then:

4. Make the schema change via `notion-update-data-source` (ALTER
   COLUMN, ADD COLUMN).
5. Update this doc + re-sync.
6. Update SKILL.md / project-instructions.md if the change affects
   workflows.

## Known constraints

- **Claude Project file caps:** ≤ 30 MB per file AND ≤ 100 pages per
  file. The 100-page cap is a visual-analysis limit; anything past it
  is text-only, which is useless for notation. Books over either cap
  must be split before upload (the `guitar-tutor` skill handles
  this).
- **Mobile cannot preprocess or modify Project files.** Book swaps,
  library maintenance, and any filesystem operation require the
  laptop.
- **Adding a new multi-select option to any DB** (new Topics value,
  new Type, new Mood) requires `notion-update-data-source` with
  ALTER COLUMN *before* creating rows that use the value.
- **Google Drive connector PDF support is flaky** — not used as an
  active pipe. The Calibre library on OneDrive is reached only via
  laptop MCP, never via Drive connector.
- **Multimedia content support is metadata-only.** Claude cannot
  watch videos, play audio, or consume any non-text/non-PDF content.
  Video courses and lesson series live in the Materials DB as
  structured metadata (topics, progress, URL) that Claude reasons
  over, but the user consumes the content on their own tools. If
  Anthropic adds native video or audio understanding to Claude,
  revisit this constraint — the Materials DB schema is already
  shaped to absorb richer content types without migration.
