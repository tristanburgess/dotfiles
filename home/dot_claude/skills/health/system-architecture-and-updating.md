# Health System — How this works

Source of truth for the Notion **Health System — How this works**
child page under the Health Area. Lives in the dotfiles repo at
`home/dot_claude/skills/health/`; synced to Notion via the `health`
skill's **Sync system doc** workflow.

Edit this file, `chezmoi apply`, then run the sync workflow to push
updates into Notion. Never edit the Notion page directly — your
edits will be overwritten on next sync.

## What the system does

Lets Claude act as training + rehab copilot across three surfaces
(laptop desktop, Claude Code CLI, mobile) with a single Notion
workspace as source of truth. The skill + Project Instructions are
intentionally **program-agnostic** and **issue-agnostic**: the
actual plan, movements, and chronic-issue criteria live in Notion,
populated by the user via dialog, not baked into any prompt.

## Architecture at a glance

```
┌─────────────────────────────────────────────────────────┐
│                  Notion — Health Area (UB)               │
│                                                          │
│  Current Training Plan (page)                            │
│  Plan Revisions (DB)                                     │
│  Workout Log (DB)                                        │
│  Exercise Library (DB)                                   │
│  Symptom Log (DB)                                        │
│  Body Metrics (DB)                                       │
│  Chronic Issues (DB of issue pages)                      │
│  Health System — How this works (this page)              │
└───────────────┬─────────────────────────────────────────┘
                │ notion MCP (laptop) / Notion connector (mobile)
   ┌────────────┴────────────────┐
   │                             │
┌──▼──────────────────┐   ┌──────▼──────────────────┐
│ Laptop              │   │ Mobile                   │
│ Claude Desktop      │   │ Claude mobile app        │
│ + MCP:              │   │ + Notion connector       │
│   notion            │   │   (read/write DBs)       │
│   filesystem        │   │ (no MCP, no skills)      │
│ + Health Project    │   │ + Health Project         │
│   Custom Instrs     │   │   Custom Instrs          │
│ + Claude Code CLI   │   │                          │
│   with `health`     │   │                          │
│   skill             │   │                          │
└─────────────────────┘   └──────────────────────────┘
```

## Per-surface capability table

| Surface | Projects | MCP | Cloud connectors | Skills | Can mutate schema |
|---|---|---|---|---|---|
| Claude Desktop (laptop) | yes | notion, filesystem | yes | no | yes via Notion MCP |
| Claude Code CLI (laptop) | no | notion, filesystem | yes | yes (`health`) | yes; only surface that runs Bootstrap + Register chronic issue |
| Claude mobile app | yes | none | yes (notion) | no | no (uses connector; can ALTER COLUMN via MCP tool calls but defers complex mutations to CLI) |
| claude.ai web | yes | none | yes (notion) | no | same as mobile |

## Notion objects under Health

All sit as children of the Health Area page. Resolve IDs at runtime
via `notion-search` — don't hardcode.

### Current Training Plan (page)

Living human-readable prescription. Sections:

- Program name + variant.
- Cycle + Program Week (sequence position, not calendar).
- Maxes with last-updated date.
- AMRAP caps (if applicable to the user's program).
- Accessory caps per equipment class.
- Day templates — one section per training day, main + accessories
  with set counts.
- Active modifications.
- Rehab / mobility integration (active + dormant).

### Plan Revisions (DB)

Append-only audit trail.

| Property | Type | Notes |
|---|---|---|
| Revision | Title | e.g., `<date> — short summary` |
| Effective Date | Date | When this revision becomes active |
| Change Type | Multi-select | max bump / accessory swap / day restructure / rehab add / rehab remove / cap change / baseline / other |
| Reason | Rich text | User's rationale |
| Diff summary | Rich text | Before/after, concrete |

### Workout Log (DB)

| Property | Type | Notes |
|---|---|---|
| Session | Title | `<YYYY-MM-DD> <Day Type> <Program Week>` |
| Date | Date (with time) | Calendar date |
| Cycle | Number | Cycle number within the active program |
| Program Week | Select | Labels from user's program (seeded at bootstrap) |
| Day Type | Select | Labels from user's program (seeded at bootstrap) |
| Main Lift Sets | Rich text | Per-set weight × reps |
| AMRAP Cap Used | Select | From user's program; `none` always valid |
| Accessories | Rich text | Movement + sets × reps × weight, one per line |
| Exercises | Relation → Exercise Library | Multi |
| Plan Revision | Relation → Plan Revisions | Which revision governed this session |
| Feel / RPE | Number (1-10) | Subjective overall |
| Post-session state | Rich text | Flare states for any relevant Chronic Issues + general notes |
| Notes | Rich text | Free-form |

### Exercise Library (DB)

| Property | Type | Notes |
|---|---|---|
| Name | Title | |
| Category | Select | Main lift / accessory / mobility / rehab / warm-up |
| Equipment | Multi-select | Barbell / dumbbell / cable / bodyweight / bands / machine / kettlebell / other |
| Muscles (primary) | Multi-select | ExRx-aligned — see vocabulary below |
| Muscles (secondary) | Multi-select | Same vocabulary |
| Default cap | Select | Default rep ceiling (e.g., ×6 BB / ×8 DB / ×10 cable), or `none` |
| Rehab issues supported | Multi-select | Conditions/issues this exercise safely accommodates during a flare-up or rehab phase; add values per condition as needed |
| Rehab substitute for | Relation → Exercise Library | Exercise(s) this replaces when the supported condition makes the original inadvisable |
| Source | Select | User program / crossover symmetry / Kit Laughlin / PT / ExRx / Catalyst Athletics / other |
| Reference link | URL | Per Reference link gate (canonical 7-tier order) |
| Notes | Rich text | Form cues, substitutions, context |

### Symptom Log (DB)

Generic — not tied to any specific issue, but may link to one.

| Property | Type | Notes |
|---|---|---|
| Entry | Title | e.g., `<YYYY-MM-DD> <short label>` |
| Date | Date (with time) | |
| Body Area | Multi-select | Cervical / upper trap L/R / shoulder L/R / scap L/R / lumbar / hip L/R / knee L/R / ankle L/R / wrist L/R / elbow L/R / other |
| Issue Type | Select | Acute-tweak / soreness / fatigue / flare-of-known-issue / sleep-related / other |
| Intensity | Number (0-10) | |
| Trigger hypothesis | Rich text | |
| What helped | Rich text | May be empty at log time |
| Linked session | Relation → Workout Log | Optional |
| Linked Chronic Issue | Relation → Chronic Issues | Optional; auto-suggested when Body Area matches a registered issue. Multi-link when both an existing pattern and a separate one are implicated. |

**Dual-mode usage.** The same schema serves two distinct usages:

- **Flare/tweak mode** — event-based. Issue Type ∈ {acute-tweak,
  soreness, fatigue, flare-of-known-issue}. Intensity reflects the
  event itself.
- **Characterisation mode** — descriptive update to an existing
  pattern. Issue Type = `other`. Intensity reflects baseline (often
  low). Narrative (mapping a tender point, an ROM observation,
  refining the picture of a known issue) goes in Trigger hypothesis
  / What helped.

Example characterisation: "2026-04-26 — inferior scap mobility
finding" maps a new tender point under Scap L; Issue Type = other;
Intensity = 2; narrative documents the finding. Linked Chronic
Issue: Left-Sided Cervico-Scapular Chain.

Trend analysis (per the **Correlate** workflow) filters on Issue
Type so characterisation entries are not mistaken for flares. Reach
for characterisation rather than registering a new Chronic Issue
when the finding refines an already-registered issue. A new Chronic
Issue is warranted only when the pattern is genuinely separate
(different etiology, different escalation criteria, different doctor
type).

### Body Metrics (DB)

Sparse, narrative-first. Primary content lives in the Note field.

| Property | Type | Notes |
|---|---|---|
| Entry | Title | Short label |
| Date | Date | When the reflection was made |
| Window | Select | Point-in-time / last few days / last week / last couple weeks / last month |
| Sleep quality | Select | Poor / mediocre / okay / good / great (qualitative, not hours) |
| Energy | Select | Low / below baseline / normal / above baseline / high |
| Weight (lb) | Number | Optional — only when user reports a specific number |
| Weight trend | Select | Optional — down / stable / up / notably up-a-few / notably down-a-few |
| Note | Rich text | Primary content |

### Chronic Issues (DB of issue pages)

One page per registered chronic concern. DB row is a thin
front-matter with a rich page body.

| Property | Type | Notes |
|---|---|---|
| Issue | Title | User's short label |
| Status | Select | Active / dormant / resolved |
| System | Select | Musculoskeletal / neurological / cardiovascular / metabolic / other |
| Onset | Date | Approximate |
| Diagnosed | Checkbox | |
| Diagnosis source | Rich text | If diagnosed: doctor/PT/imaging |
| Body Areas | Multi-select | Same vocabulary as Symptom Log Body Area |

Page body sections (populated during **Register chronic issue**):

- **Characterisation** — onset, symptoms, triggers, relievers,
  current management, context.
- **Escalation criteria** — issue-specific, written in user's words
  at registration time: what triggers a flag-to-doctor, what
  triggers urgent care.
- **Log** — linked Symptom Log rows.
- **Interventions tried** — running history.
- **Doctor-prep summary** — regenerated before planned visits.

### Protocols (DB)

Cross-cutting protocols that wrap around the main program — rehab
blocks, mobility routines, soft-tissue work, warmup/cooldown
systems, weakness-fix prioritisation, etc. Tracked separately from
the Current Training Plan page so they have lifecycle (active /
dormant / archived) and so they can be linked from Workout Log,
Chronic Issues, and Plan Revisions.

| Property | Type | Notes |
|---|---|---|
| Protocol | Title | Short label |
| Status | Select | Active / Dormant / Archived / Experimental |
| Type | Multi-select | Rehab / Mobility / Stability / Soft Tissue / Warmup / Cooldown / Activation / Weakness Fix / Other |
| Slot | Multi-select | Morning / Pre-gym / In-gym / Post-gym / Off-gym block / Pre-bed / On-demand / Daily anytime |
| Frequency | Rich text | e.g., `Daily`, `3×/week`, `Each gym day` |
| Duration (min) | Number | Approximate per-session minutes |
| Targets Chronic Issue | Relation → Chronic Issues (DUAL `Protocols`) | Multi |
| Exercises | Relation → Exercise Library (DUAL `Used in Protocols`) | Multi |
| Source | Select | PT / Kit Laughlin / ExRx / Catalyst Athletics / Self-derived / Other |
| Activated Date | Date | When status went Active |
| Deactivated Date | Date | When status left Active |
| Linked Plan Revision | Relation → Plan Revisions (DUAL `Protocols`) | Activation / deactivation audit trail |
| Notes | Rich text | Per-protocol cues, structure, body-content pointer |

Per-protocol prescription detail (warmup sequence, set/rep
structure, day variants, cues) lives in the **page body** of each
row — DB properties stay shape-only.

Default view: filtered to `Status = Active`, sorted by Activated
Date desc.

The DUAL relations mean each Chronic Issue page surfaces a
`Protocols` reverse-relation (which protocols target this issue),
each Exercise Library row surfaces `Used in Protocols`, and each
Plan Revisions row surfaces `Protocols` (which protocols this
revision activated or deactivated).

## Muscle vocabulary (ExRx-aligned)

Used as multi-select values on Exercise Library. Seed via ALTER
COLUMN at bootstrap, before creating any row.

- Chest: Pectoralis Major Sternal, Pectoralis Major Clavicular,
  Pectoralis Minor, Serratus Anterior.
- Back: Latissimus Dorsi, Teres Major, Rhomboids, Trapezius Upper,
  Trapezius Middle, Trapezius Lower, Erector Spinae, Infraspinatus,
  Teres Minor.
- Shoulders: Deltoid Anterior, Deltoid Lateral, Deltoid Posterior,
  Supraspinatus, Subscapularis.
- Arms: Biceps Brachii, Brachialis, Brachioradialis, Triceps Brachii
  (long head), Triceps Brachii (lateral/medial).
- Forearms: Wrist Flexors, Wrist Extensors.
- Core: Rectus Abdominis, Obliques, Transverse Abdominis,
  Quadratus Lumborum.
- Hips/Glutes: Gluteus Maximus, Gluteus Medius, Gluteus Minimus,
  Tensor Fasciae Latae, Iliopsoas, Adductors.
- Legs: Quadriceps (Rectus Femoris), Quadriceps (Vasti), Hamstrings
  (Biceps Femoris), Hamstrings (Semitendinosus/Semimembranosus),
  Gastrocnemius, Soleus, Tibialis Anterior.
- Neck/Cervical: Sternocleidomastoid, Scalenes, Deep Cervical
  Flexors, Splenius (Capitis/Cervicis), Levator Scapulae.

Coaching surfaces translate to casual anatomy in conversation;
schema values stay formal for queryability.

## Reference link validation (hard gate)

Every Exercise Library row's `Reference link` must point to media
that visibly demonstrates *this exact exercise by this name*. The
gate runs at row create + update time, in **Bootstrap Health
workspace** step 8 and **Log workout** step 4 (in-flight create), and
again whenever a workflow re-touches an existing row's
`Reference link`. On gate failure, the workflow refuses to write the
link and either prompts the user for a replacement or saves the row
with `Reference link` empty + a `Notes` annotation.

### Valid-link criteria

A `Reference link` value is **valid** iff both:

1. The URL fetches successfully and the rendered page or video
   clearly demonstrates the exercise on the row, by the name on the
   row. Verification is by *content*, not by URL slug.
2. The source is one of:
   - `exrx.net` direct movement page (preferred for cataloged lifts;
     ExRx may block headless fetches but is treated as authoritative
     when the URL pattern matches a known ExRx exercise path).
   - `catalystathletics.com/exercise/<id>/<slug>/` where the rendered
     page content matches the row name. **The `<id>` segment is
     canonical; the `<slug>` is cosmetic and routinely mismatches.**
     Always fetch and verify content, never trust the slug.
   - `crossoversymmetry.com` page or their official YouTube channel.
   - `yogajala.com` direct pose page — for yoga-named mobility
     movements (Malasana, Parsva Sukhasana, Paschimottanasana,
     Anjaneyasana, Ardha Matsyendrasana, etc.). Verify by fetching;
     page must describe the pose named on the row.
   - Reputable third-party fitness publisher direct exercise page —
     `musclewiki.com`, `muscleandstrength.com`, `healthline.com`,
     `verywellfit.com`, `spine-health.com`, `hingehealth.com`, or
     equivalent. Use as a fallback when ExRx / Catalyst / yogajala
     don't cover the movement. The page must be a direct
     single-exercise guide that names the exercise in the title and
     describes it in body content; reject category listings,
     "best X exercises" roundups, and articles that only mention
     the exercise in passing.
   - `youtube.com/watch?v=...` from Kit Laughlin / Stretch Therapy,
     Jim Wendler / 5-3-1 official, Crossover Symmetry, or another
     reputable PT/coach.
     - **If the video covers more than one exercise** (compilation,
       flow, "session", multi-stretch sequence), the URL **must**
       carry a `?t=Xs` or `&t=Xs` timestamp parameter that lands at
       the exercise. Untimestamped multi-exercise videos fail the
       gate.

### Source preference order

When picking or replacing a link:

```
ExRx (cataloged lift)
  → Catalyst Athletics (id-verified content match)
  → official source matching the row's `Source` field
     (Kit Laughlin / 5-3-1 / Crossover Symmetry / PT)
  → yogajala.com (yoga-named movements)
  → reputable third-party publisher direct exercise page
     (musclewiki / muscleandstrength / healthline / verywellfit /
     spine-health / hingehealth)
  → reputable coach YT (timestamped if multi-exercise)
  → empty + Notes annotation
```

### Discovery methodology — search, fetch, verify

Don't guess URLs from the slug pattern of a preferred source. Slug
guessing is what produced the 2026-04-27 audit regressions (Catalyst
slugs that mismatched the page they served). Discover candidate
URLs by querying for the exercise *name*, then verify each candidate
by fetching its content.

Procedure for any row that needs a `Reference link` (new row, broken
link, or audit re-check):

1. **Search** for the exercise name with a broad query that doesn't
   commit to a single domain. Bias toward the source preference
   order via an `OR` site filter, not a single `site:` constraint:
   ```
   "<exercise name>" exercise guide
     site:exrx.net OR site:catalystathletics.com
     OR site:yogajala.com OR site:musclewiki.com
     OR site:healthline.com
   ```
   Use `WebSearch` (or equivalent). Pull the top 3-5 candidates.
2. **Fetch** the top candidate URL with `WebFetch`. Ask the fetch
   prompt to summarise: page title, what exercise the page describes,
   whether the body content references this exercise by name, and
   whether the instructions match the movement pattern implied by
   the name.
3. **Verify**. The candidate passes only if all of:
   - Page returns 200 (not 404, not a generic results / category page).
   - Title or H1 matches the row's `Name` (allow casing / hyphenation
     variation; reject when the page describes a different movement
     family).
   - Body content references the exercise *by name* and the
     instructions are consistent with the movement.
   - Source is in the preferred source list (per *Valid-link
     criteria*).
4. **Walk down the candidate list** if the top result fails — try
   the next, up to ~5. Don't widen sources beyond the preferred list.
5. **Update** the row's `Reference link` only when a candidate passes
   the gate. Otherwise leave the link empty + apply the no-public-
   demo escape hatch annotation. Better blank than wrong: an
   unverified URL is worse than no URL because the user may tap it
   on mobile mid-warmup.

This methodology supersedes any flow that constructs a candidate URL
by templating the exercise name into a known site's slug pattern.

### No-public-demo escape hatch

For PT-prescribed or otherwise idiosyncratic exercises that have no
public demo meeting the criteria, leave `Reference link` empty and
append to `Notes`:

```
[<YYYY-MM-DD> audit: <previous URL or "no public demo on file">
removed/missing — <one-line reason>. Needs validated single-exercise
demo or timestamped (?t=Xs) link.]
```

This is the only sanctioned way to leave a row without a link.

### Workflow obligation

Any workflow that creates or modifies an Exercise Library
`Reference link` must, before calling `notion-create-pages` /
`notion-update-page`:

1. Discover the candidate URL via *Discovery methodology* above —
   broad-query search for the exercise name, biased to the preferred
   sources via `site: A OR site: B`, never by templating a slug.
2. Fetch the candidate URL (`WebFetch` or equivalent).
3. Confirm the rendered content matches the row's `Name` by *content*
   (page title / H1, body references the exercise by name,
   instructions consistent with the movement pattern). Reject 404s,
   generic results / category pages, and pages describing a
   different movement.
4. For YouTube: confirm timestamp policy if the video isn't dedicated
   to a single exercise.
5. On failure: walk down the candidate list (up to ~5). If still no
   pass, refuse to write the link and fall back to the no-public-
   demo escape hatch (empty + Notes annotation). Better blank than
   wrong.

Pattern observed during the 2026-04-27 audit (regression cases to
test against on any future tooling):

- Catalyst URL `/exercise/691/Foam-Roller-Thoracic-Extension/`
  actually serves **Floating Power Clean** — gate must reject.
- Catalyst URL `/exercise/621/Prone-T-Y-W-Raise/` actually serves
  **Pause Quarter Back Squat Jump** — gate must reject.
- YouTube `watch?v=z2ghLlUPRuU` is "Mobilising and stretching
  session, focus on hips" (a compilation) — gate must reject when
  used without a `?t=` timestamp on a single-exercise row.

## Where each capability lives

| Capability | Where defined | Surface |
|---|---|---|
| Session coaching + day-of adjustment | Health Project Custom Instructions | Desktop, mobile, web |
| Workout logging | Health Project Custom Instructions + `health` skill | Any surface with Notion access |
| Symptom logging | Health Project Custom Instructions + `health` skill | Any surface with Notion access |
| Body Metrics entries | Health Project Custom Instructions | Any surface with Notion access |
| Notion MCP operational gotchas | Health Project Custom Instructions | Desktop (mobile uses cloud connector, fewer gotchas apply) |
| Bootstrap workspace | `health` skill | Claude Code CLI (laptop) |
| Register chronic issue | `health` skill | Claude Code CLI (laptop); can also run from Desktop if user prefers |
| Register / activate / deactivate protocol | `health` skill | Claude Code CLI (laptop) |
| Self-assessment intake | Health Project Custom Instructions | Any surface (vision-capable) |
| Correlate logs | `health` skill | Claude Code CLI (laptop) |
| Revise training plan | `health` skill + Health Project Custom Instructions | Either; CLI recommended for rich diffs |
| Sync this doc → Notion | `health` skill's Sync workflow | Claude Code CLI |
| Per-issue escalation criteria | Generated at Register time; stored on the issue page | Read by all surfaces at runtime |

## Self-assessment intake

The user may share annotated photos circling spots, ROM tests,
stability tests, or other functional self-assessments. Treat as data
for refining the protocol — not as a diagnosis.

- Map circles / pointers to likely anatomy. Name the structures.
- Suggest an interpretation; explicitly flag what is inference vs
  what is observable.
- For notable findings: log a Symptom Log characterisation entry
  (Issue Type = `other`) linked to the relevant Chronic Issue.
- For clearly out-of-scope findings (e.g., something that needs a PT
  or doctor's hands-on assessment): say so, and queue the finding
  for the Doctor-prep summary on the relevant Chronic Issue page.

This workflow is reusable for future flares. Visual / functional
self-assessment is data, not diagnosis.

## Update loop — how to change the system

### Editing coaching behaviour

1. Edit
   `home/dot_claude/skills/health/project-instructions.md` in the
   dotfiles repo.
2. `chezmoi apply` (no-op for this file — it's a paste target).
3. Copy the file's body into Claude Desktop → Health Project →
   Custom Instructions. Save.

The paste is manual because Anthropic exposes no API for Project
Custom Instructions.

### Editing skill workflows

1. Edit `home/dot_claude/skills/health/SKILL.md` in the dotfiles
   repo.
2. `chezmoi apply` — deploys to
   `~/.claude/skills/health/SKILL.md`.
3. Restart Claude Code CLI (or start a new session). Changes active.

### Editing this architecture doc

1. Edit
   `home/dot_claude/skills/health/system-architecture-and-updating.md`.
2. `chezmoi apply`.
3. In Claude Code CLI, run the `health` skill's **Sync system doc**
   workflow → pushes content into the Notion page you're reading
   right now.

### Schema changes under the Health Area

Bootstrap only *adds* a Health Area + new children; it does not
mutate UB core DBs. A pre-bootstrap full-UB export is offered but
not required.

For later schema changes (new column, ALTER COLUMN, new DB):

- **Additive changes** (adding a new multi-select option never used
  yet, adding a new column): run directly via
  `notion-update-data-source`. Backup optional.
- **Destructive changes** (renaming / deleting an option already
  used, deleting a column, merging DBs): export first to
  `~/OneDrive/Documents/notion-backups/ub-pre-<change>-<date>.zip`
  (Notion UI → Settings → Export → Everything → Markdown & CSV).
  Test on a sandbox page if touching anything interacting with
  Ultimate Brain's core DBs (this skill's DBs don't).

After any schema change: update this doc + re-sync; update
`SKILL.md` / `project-instructions.md` if workflows need to change.

### Registering a new chronic issue

1. Run **Register chronic issue** workflow from the `health` skill
   (or inline from Desktop if preferred).
2. Interview the user; capture characterisation.
3. Generate escalation criteria **with the user**, in their words.
   Don't import a universal list.
4. Create the issue page under Chronic Issues.
5. The coaching surfaces now read the criteria from the page.

## Known constraints

- **No diagnostic authority.** The skill logs, analyses, and flags
  based on user-written per-issue criteria. It doesn't replace a
  doctor or PT.
- **Program-agnostic by design.** If the user switches programs, run
  a Plan Revision (Change Type: day restructure) or re-seed Program
  Week / Day Type vocabulary via ALTER COLUMN — don't edit the
  skill's prompts to match a new program.
- **Mobile cannot run the `health` skill.** Bootstrap and correlation
  analysis require Claude Code CLI.
- **Adding a new multi-select option requires ALTER COLUMN first.**
  Always before creating a row that uses the value.
- **Exact sleep hours and daily bodyweight are not tracked.** Body
  Metrics is narrative + qualitative by design. Numeric fields are
  optional.
