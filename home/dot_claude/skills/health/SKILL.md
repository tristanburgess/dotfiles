---
name: health
description: Maintain the Notion Health workspace — current training plan, workout log, exercise library, symptom log, body metrics, chronic-issue pages — that backs the user's body-health project. Use when bootstrapping the workspace, logging a workout, adjusting a day-of prescription, revising the training plan, logging symptoms, registering a chronic issue, correlating patterns across logs, or syncing the system doc. Claude Code CLI only (notion MCP required). Routine session coaching also lives in the Health Project's Custom Instructions; workflows here cover bootstrap, schema, and cross-log analysis the Desktop Project can't safely do.
---

# Health — maintenance

Keeps the Notion **Health** workspace in sync with training + rehab
reality. Source of truth for every workflow, all children of the
Health parent page (exact placement in the workspace — Area, Project,
standalone page — is user-specific and confirmed at bootstrap):

- **Current Training Plan** (page) — living prescription.
- **Plan Revisions** (DB) — append-only audit trail for every plan
  change.
- **Workout Log** (DB) — one row per session.
- **Exercise Library** (DB) — movement catalog, ExRx-aligned.
- **Symptom Log** (DB) — any body-area issue over time.
- **Body Metrics** (DB) — sparse, narrative-first check-ins.
- **Chronic Issues** (DB of pages) — one page per registered ongoing
  concern (created on demand via **Register chronic issue**; none
  assumed at bootstrap).
- **Health System — How this works** (page) — synced from the
  architecture doc in this skill.

**Surface:** Claude Code CLI on the laptop. Requires `notion` MCP
server. Mobile and Claude Desktop coaching surfaces read/write the
same DBs via the Notion connector / MCP, but schema mutations and
bootstrap go through this skill only.

**Scope — program-agnostic, issue-agnostic.** The skill's workflows,
schema, and vocabulary assume no specific training program, split,
accessory list, or chronic condition. The user's actual program
lives in the Current Training Plan page + Exercise Library rows,
populated during the bootstrap dialog. Chronic issues are registered
on demand, each with its own page + user-specific diagnostic-escalation
criteria generated at registration time. Don't bake program-specific
or condition-specific content into this skill.

## Cadence model — sequence-position vs calendar

Many strength programs progress by **completed sessions**, not by
the calendar. The skill models both:

- **Program Week** (Workout Log) = sequence position in the program's
  cycle. Labels (e.g., `wk1` / `wk2` / `wk3`, or `intensification` /
  `accumulation`, or whatever the user's program uses) are seeded
  from the user's actual program at bootstrap. The skill doesn't
  assume a label set.
- **Date** (Workout Log) = calendar date the session happened.

Program Week advances only when a session is logged. Never infer
"behind schedule" from elapsed calendar days. The user decides
frequency; the log records reality.

Only flag readiness concerns on **multi-week gaps** (≥ 3 calendar
weeks with zero sessions) — suggest a warm-back-in deload, don't
nag.

## Data-source resolution

Resolve every DB + page at runtime via `notion-search`. Do not
hardcode IDs — they're environment-specific.

On first run of any workflow in a conversation, resolve and cache:

```
notion-search "Workout Log"
notion-search "Exercise Library"
notion-search "Symptom Log"
notion-search "Plan Revisions"
notion-search "Body Metrics"
notion-search "Current Training Plan"   # page, not DB
notion-search "Chronic Issues"          # DB of issue pages
notion-search "Protocols"               # cross-cutting protocol DB
```

If the core DBs return nothing → run **Bootstrap Health workspace**
before proceeding. Chronic Issues may be empty; that's normal.

## Exercise references

Default references, in preference order:

1. **exrx.net** (`https://exrx.net/Lists/Directory`) — movement
   descriptions, primary/secondary musculature, mechanical analysis.
2. **Catalyst Athletics exercise library**
   (`https://www.catalystathletics.com/exercises/`) — form cues and
   supplemental movement ideas. The user can't do Olympic lifting
   but still values the form detail and accessory coverage.
3. **yogajala.com** direct pose page — for yoga-named mobility
   movements (asana, pranayama, stretch flows). Prefer when the
   exercise name maps to a named yoga pose or is derived from one
   (e.g., Malasana, Parsva Sukhasana, Paschimottanasana, Anjaneyasana).
   Verify content match by fetching the URL.
4. **Reputable third-party fitness publisher direct exercise page**
   — musclewiki.com, muscleandstrength.com, healthline.com,
   verywellfit.com, or equivalent. Use when ExRx / Catalyst /
   yogajala don't cover the movement. Must be a direct
   single-exercise guide, not a roundup or category page.
5. **Single-exercise YouTube** from the row's `Source` channel — Kit
   Laughlin / Stretch Therapy, Jim Wendler / 5-3-1 official, Crossover
   Symmetry official, or another reputable PT/coach when ExRx and
   Catalyst don't cover the variant.

Fill `Reference link` on the Exercise Library row with the best
direct page that **demonstrates this exercise by this name**.

**Discover candidates by search, not by slug guessing.** Run a
broad-query search for the exercise name biased toward the preferred
sources (`"<name>" exercise guide site:exrx.net OR site:catalystathletics.com
OR site:yogajala.com OR site:musclewiki.com OR site:muscleandstrength.com
OR site:healthline.com`), pull the top 3-5 candidates, then fetch
and verify each one against the row's `Name` and movement pattern.
Walk down the list when a candidate fails. Don't construct a URL by
templating the exercise name into a known site's slug pattern — that
practice produced the 2026-04-27 audit regressions and is now
prohibited. Full procedure in the architecture doc § *Discovery
methodology*.

## Reference link validation (hard gate)

Every Exercise Library row's `Reference link` must point to media
that visibly demonstrates *this exact exercise*, not a related
movement or a compilation it's buried inside. Enforced at row
create + update time — see the full gate spec in
`system-architecture-and-updating.md` § Reference link validation.

Summary of the gate:

- **Discover by search, not by slug guessing.** For any row that
  needs a link, run a broad-query search for the exercise name
  (`"<name>" exercise guide site:exrx.net OR site:catalystathletics.com
  OR site:yogajala.com OR site:musclewiki.com OR site:healthline.com`),
  pull the top 3-5 candidates, and verify each by fetching the page.
  Walk down the list when a candidate fails. Never construct a URL
  by templating the exercise name into a known site's slug pattern —
  that's what produced the 2026-04-27 audit regressions.
- **Verify content match by fetching the URL**, not by trusting the
  slug. Catalyst Athletics URLs of the form
  `catalystathletics.com/exercise/<id>/<slug>/` are canonical on
  `<id>` only — the `<slug>` is cosmetic and routinely mismatches
  the rendered page (this audit found `/691/Foam-Roller-Thoracic-
  Extension/` actually serves Floating Power Clean).
- **YouTube videos that aren't dedicated to one exercise must carry a
  `?t=Xs` (or `&t=Xs`) timestamp** that lands at the exercise.
  Untimestamped multi-exercise / flow / "session" videos fail the
  gate.
- **Source preference order:** ExRx (cataloged lift) → Catalyst
  Athletics (id-verified content match) → official source matching
  the row's `Source` field → yogajala.com (yoga-named movements) →
  reputable third-party fitness publisher direct exercise page
  (musclewiki / muscleandstrength / healthline / verywellfit) →
  reputable coach YT (timestamped if multi-exercise) → leave
  `Reference link` empty + annotate `Notes` with `"<previous URL or
  "no public demo found"> — needs validated single-exercise demo or
  timestamped link"`.
- **Never fabricate a link.** Empty + Notes annotation beats a
  misleading reference. Better blank than wrong — an unverified URL
  on mobile mid-warmup is worse than no URL.

Apply the gate in **Bootstrap Health workspace** step 8 (seed) and in
**Log workout** step 4 (in-flight Exercise Library row create). On
failure, refuse to write the link and prompt the user.

For **Protocols DB** rows, always populate `Reference link` when
`Source` is not Self-derived: use the official source page or a
video (YouTube preferred for mobility/technique protocols). When
creating a new Protocol row in any workflow, search for a reference
URL before writing the row.

## Muscle vocabulary — ExRx-aligned

The Exercise Library's `Muscles (primary)` and `Muscles (secondary)`
multi-selects use ExRx-style granularity. Seed via
`notion-update-data-source` ALTER COLUMN during bootstrap, before
creating any Exercise Library row.

- **Chest:** Pectoralis Major Sternal, Pectoralis Major Clavicular,
  Pectoralis Minor, Serratus Anterior.
- **Back:** Latissimus Dorsi, Teres Major, Rhomboids, Trapezius Upper,
  Trapezius Middle, Trapezius Lower, Erector Spinae, Infraspinatus,
  Teres Minor.
- **Shoulders:** Deltoid Anterior, Deltoid Lateral, Deltoid Posterior,
  Supraspinatus, Subscapularis.
- **Arms:** Biceps Brachii, Brachialis, Brachioradialis, Triceps
  Brachii (long head), Triceps Brachii (lateral/medial).
- **Forearms:** Wrist Flexors, Wrist Extensors.
- **Core:** Rectus Abdominis, Obliques, Transverse Abdominis,
  Quadratus Lumborum.
- **Hips/Glutes:** Gluteus Maximus, Gluteus Medius, Gluteus Minimus,
  Tensor Fasciae Latae, Iliopsoas, Adductors.
- **Legs:** Quadriceps (Rectus Femoris), Quadriceps (Vasti),
  Hamstrings (Biceps Femoris), Hamstrings
  (Semitendinosus/Semimembranosus), Gastrocnemius, Soleus, Tibialis
  Anterior.
- **Neck/Cervical:** Sternocleidomastoid, Scalenes, Deep Cervical
  Flexors, Splenius (Capitis/Cervicis), Levator Scapulae.

Formal names are for schema values. In conversation, translate to
casual anatomy when that reads better ("front delts" for Deltoid
Anterior, "traps" for Trapezius Upper, "lats" for Latissimus Dorsi,
etc.). The user does not need the formal name every time.

## Workflow: Bootstrap Health workspace

Purpose: create the Health Area + DBs + pages + seed vocabularies on
first run. Idempotent via existence checks per step.

**Optional backup:** bootstrap only *adds* a Health Area + new
children; it does not mutate Ultimate Brain core DBs (Tasks, Notes,
Projects). A full UB export is not required. Offer it as a
precaution (`Notion UI → Settings → Export → Everything → Markdown
& CSV` → `~/OneDrive/Documents/notion-backups/ub-pre-health-<date>.zip`)
and proceed when the user has either backed up or declined.

Steps:

1. **Resolve or create Health parent page.** Ask the user where they
   want Health to live (new Area page, existing Project, child of a
   specific page, etc.) — don't assume. Confirm the name (`Health`,
   `Body`, or whatever the user prefers). Locate the target parent
   via `notion-search` and create the Health page/row there if
   missing.
2. **Gather program specifics from the user** in dialog — do not
   assume. Ask for:
   - Program name + variant.
   - Maxes / training maxes — one entry per main lift, last-updated
     date.
   - Program-week labels + what each represents.
   - AMRAP / self-cap conventions, if any.
   - Accessory caps per equipment class, if any.
   - Day templates: for each training day, day type + accessories
     (name + set count).
   - Active modifications / substitutions.
   - Dormant rehab/mobility available for reintegration.
3. **Create DBs** under Health, in this order (relations depend on
   earlier DBs existing):
   1. Exercise Library (no inbound relations).
   2. Plan Revisions (no inbound relations).
   3. Workout Log (relations → Exercise Library, Plan Revisions).
   4. Symptom Log (relation → Workout Log; relation → Chronic Issues
      once that DB exists).
   5. Body Metrics (no relations).
   6. Chronic Issues (no inbound relations at create time; Symptom
      Log's relation to it is wired after both exist).
   7. Protocols (relations → Chronic Issues, Exercise Library, Plan
      Revisions; all DUAL — back-relations named `Protocols` on each
      target DB, except Exercise Library which uses
      `Used in Protocols`).
   Full schema per DB is in the architecture doc
   (`system-architecture-and-updating.md`).
   Each step is existence-checked first via `notion-search` — only
   create what's missing. Re-running bootstrap on an established
   workspace must be a no-op for already-present DBs.
4. **Seed multi-select vocabularies** via `notion-update-data-source`
   ALTER COLUMN before any row creation:
   - Exercise Library: `Category`, `Equipment`, `Muscles (primary)`,
     `Muscles (secondary)`, `Default cap`, `Source`,
     `Rehab issues supported` (seed empty; add values per condition
     as active issues are registered).
   - Workout Log: `Day Type` (from step 2), `Program Week` (from
     step 2), `AMRAP Cap Used` (from step 2, or `none` only),
     general-body-area `Post-session state` area.
   - Symptom Log: `Body Area` (seed the full cervical-through-lower-
     body list, left/right where bilateral), `Issue Type` (e.g.,
     acute-tweak, soreness, fatigue, flare-of-known-issue, other).
   - Plan Revisions: `Change Type` (e.g., max bump, accessory swap,
     day restructure, rehab add, rehab remove, cap change, other).
   - Body Metrics: `Window`, `Sleep quality`, `Energy`,
     `Weight trend`.
   - Chronic Issues: `Status` (active / dormant / resolved),
     `System` (musculoskeletal, neurological, cardiovascular,
     metabolic, other).
   - Protocols:
     - `Status` (Active / Dormant / Archived / Experimental).
     - `Type` (Rehab / Mobility / Stability / Soft Tissue / Warmup
       / Cooldown / Activation / Weakness Fix / Other).
     - `Slot` (Morning / Pre-gym / In-gym / Post-gym / Off-gym
       block / Pre-bed / On-demand / Daily anytime).
     - `Source` (PT / Kit Laughlin / ExRx / Catalyst Athletics /
       Self-derived / Other).
5. **Create Current Training Plan page** as a child of Health. Body
   reflects the user's responses from step 2. See *Current Training
   Plan — page structure* below for the expected section layout.
6. **Create Health System page** as a child of Health; run **Sync
   system doc** to populate it.
7. **Append initial Plan Revisions row** dated today recording
   baseline state (Change Type: `baseline`, Reason: "initial
   bootstrap").
8. **Seed Exercise Library** with one row per movement the user
   listed in step 2. Each row gets primary + secondary muscles from
   the ExRx vocabulary, default cap per equipment, and a reference
   link (ExRx preferred, Catalyst fallback) when a direct page
   exists. **Every seeded row's `Reference link` runs the validation
   gate** (see *Reference link validation* above). On gate failure,
   leave the link empty and annotate `Notes` per the spec rather than
   writing an unverified URL.
9. **Populate the homepage** — replace the Health project page body
   with:
   - **Quick Reference** — current TMs, cycle, program week.
   - **Navigation** — named links to each DB and page.
   - **How to Interact with Claude** — prompts for each workflow:
     log workout, get day-of prescription, log symptom, body
     check-in, update plan, correlate, chronic issue work, register
     new issue.
   - **Red flags summary** — condensed escalation criteria for each
     registered Chronic Issue.
   - **Quick Prompts table** — one-liner copy/paste phrases.
   - **Inline DB views** — Workout Log and Symptom Log embedded
     with `<database url="..." inline="true">` tags.

   **CRITICAL:** use `notion-update-page` with `update_content`
   (old_str / new_str pairs), not `replace_content`. The Health
   project page has child databases and pages; `replace_content`
   with `allow_deleting_content: true` will trash any child not
   explicitly referenced in the new body. If a full body replacement
   is truly necessary, fetch the current page first and include
   every child as `<database url="...">` or `<page url="...">` in
   the new content before calling replace_content.

   Update the homepage whenever TMs change, program week advances
   past a milestone, or a new Chronic Issue is registered.

Report at the end: IDs of each created DB + page + row count seeded.

Chronic Issues DB stays empty until **Register chronic issue** runs.

## Workflow: Register chronic issue

Purpose: add a chronic / ongoing concern to the Chronic Issues DB
with a dedicated page, and generate **issue-specific escalation
criteria** at registration time — not from a static list in this
skill.

Triggered when the user introduces a new ongoing concern (chronic
pain, chronic fatigue, a diagnosed condition, a recurring flare
pattern, anything they want tracked across time).

Steps:

1. Resolve the Chronic Issues DB.
2. **Interview the user** to characterise the issue. At minimum
   capture:
   - Name / short label (user's own wording).
   - System (musculoskeletal / neurological / cardiovascular /
     metabolic / other).
   - Onset (approximate).
   - Diagnosed? If yes, diagnosis + source (doctor, PT, imaging).
   - Primary symptoms — location, character, intensity range.
   - Known triggers — what provokes flares.
   - Known relievers — what helps.
   - Current management — meds, PT exercises, mobility routines,
     behavioural changes.
   - Relevant context — lifestyle, mechanical factors, prior
     interventions.
3. **Generate escalation criteria** with the user. For this specific
   issue, what would constitute:
   - A **flag-to-doctor** event? (New symptom type, neurological
     signs specific to the affected area, duration / intensity
     threshold worsening, failure of known relievers, etc.)
   - An **urgent-care** event? (Red-flag signs for this specific
     issue.)
   Write the criteria in the user's words, validated back to them.
   Don't invent thresholds the user didn't agree to.
4. Create the page in Chronic Issues with sections:
   - Characterisation (from step 2).
   - Escalation criteria (from step 3).
   - Log (links to Symptom Log rows tagged with this issue).
   - Interventions tried (running history).
   - Doctor-prep summary (regenerated when the user plans a visit).
5. Wire the Symptom Log relation: when Body Area on a Symptom Log
   row overlaps this issue's affected area, suggest linking the row
   to the issue page via relation.

The escalation criteria live on the issue page, not in this skill.
Coaching surfaces read them at runtime to know when to flag the user
toward professional care.

## Workflow: Register protocol

Purpose: add a cross-cutting protocol (rehab block, mobility routine,
soft-tissue work, warmup/cooldown system, weakness-fix prioritisation,
etc.) to the Protocols DB. Run when the user adopts a new protocol
that wraps around the main program.

Steps:

1. Resolve Protocols, Chronic Issues, Exercise Library, Plan Revisions
   data sources via `notion-search`.
2. **Interview** the user to characterise the protocol:
   - Name (short title).
   - Type — multi-select from the seeded vocabulary.
   - Slot — multi-select; when in the day/week does it run.
   - Frequency (free text, e.g., `Daily`, `3×/week`,
     `Each gym day`).
   - Duration (min) — approximate.
   - Source — PT / Kit Laughlin / ExRx / Catalyst Athletics /
     Self-derived / Other.
   - Target Chronic Issue(s) — link to existing rows; if a target
     isn't yet registered and should be, branch to **Register
     chronic issue** first.
   - Exercises — for each movement, resolve to an Exercise Library
     row. Create rows for any that don't exist (Category, Equipment,
     Muscles, Source, Reference link — ExRx first, Catalyst
     fallback). Skip `Rehab issues supported` /
     `Rehab substitute for` at create time — backfill as needed.
   - Notes — per-protocol cues, structure, body-content pointer.
3. Create the Protocols row:
   - `Status = Active`.
   - `Activated Date = today`.
   - Wire `Targets Chronic Issue` and `Exercises` relations.
4. Optional but default-yes: append a Plan Revisions row of
   `Change Type = rehab add` recording the activation, and link via
   `Linked Plan Revision`. Diff summary: short prose describing what
   changed in the user's overall integration (e.g., "Activated
   Scap+Core Foundation Block 3×/week off-gym").
5. Populate the row's page body with the per-protocol prescription
   (warmup sequence, set/rep structure, day variants, cues). Body
   detail is what coaching surfaces read; DB properties stay
   shape-only.

## Workflow: Activate protocol / Deactivate protocol

Purpose: flip a registered protocol's lifecycle state with audit
trail.

Triggered when:
- The user starts (re-starts) using a protocol previously paused.
- The user pauses or retires a protocol.

Steps:

1. Resolve the Protocols row by name via `notion-search`.
2. **Activate**:
   - Set `Status = Active`.
   - Set `Activated Date = today`. Clear `Deactivated Date`.
3. **Deactivate**:
   - Set `Status = Dormant` by default. If user states the protocol
     is permanently retired, use `Archived`.
   - Set `Deactivated Date = today`.
4. Append a Plan Revisions row:
   - `Change Type = rehab add` (Activate) or `rehab remove`
     (Deactivate).
   - Reason: user's rationale.
   - Diff summary: `Activated: <name>` or `Deactivated: <name>`.
   - Effective Date: today.
5. Link the new Plan Revisions row back to the protocol via
   `Linked Plan Revision`.

Never delete a protocol row. Lifecycle is encoded by Status + dates.

## Workflow: Log workout

Purpose: create a Workout Log row from a session description.

1. Resolve Workout Log, Exercise Library, Plan Revisions data-source
   IDs via `notion-search` (cache for this conversation).
2. Identify the **active Plan Revision** = most recent Plan Revisions
   row by `Effective Date ≤ today`. Cache its page ID.
3. Parse the session description into structured form:
   - Day Type (from the active plan's day template vocabulary).
   - Program Week — infer from rep scheme when unambiguous; ask
     otherwise.
   - Main lift per-set weight × reps.
   - AMRAP cap used, when the program week prescribes an AMRAP set.
   - Accessories with sets × reps × weight.
   - Feel / RPE (1-10) — ask if not volunteered.
   - Post-session state for any registered Chronic Issues whose
     body area is relevant to today's session — always ask at
     session end if not volunteered. Options reflect the issue's
     flare states (or generic Fine / mild / notable / flared if
     none registered).
4. For each accessory, resolve to an Exercise Library row by name.
   If unknown → create a new row in-flight (prompt for category,
   equipment, muscles, reference link). The in-flight row's
   `Reference link` runs the validation gate (see *Reference link
   validation*). If no validated link is available at session time,
   save the row with `Reference link` empty + `Notes` annotation per
   the spec and continue the session — don't block logging on a
   missing reference. Skip `Rehab issues supported` and `Rehab
   substitute for` on in-flight rows — fill those when setting up
   subs for a registered issue, not mid-session.
5. Create the Workout Log row:
   - Title format: `<YYYY-MM-DD> <Day Type> <Program Week>`.
   - Multi-select fields as JSON array strings.
   - `Plan Revision` relation → active revision.
   - `Exercises` relation → main lift + all accessory rows.
6. **Flag plan deviations** inline (in Notes + conversation):
   - Weight below what the active plan prescribes → ask whether the
     plan should revise or this was a bad-day call.
   - AMRAP self-cap exceeded → note it, don't flag as bad (self-cap
     is user-directed).
   - New accessory not on the day template → note, consider for plan
     revision.

## Workflow: Plan day-of adjustment

Purpose: prescribe today's session when the user opens the
conversation mid-week.

1. Resolve Current Training Plan page + active Plan Revision + last
   7 days of Workout Log + last 14 days of Symptom Log + active
   Chronic Issues.
2. Infer today's session type from the day rotation in the active
   plan + the last Workout Log Day Type.
3. Compute prescribed sets from active maxes + Program Week
   advancing rules (from the active plan page).
4. Apply modifications from the active Plan Revision (current subs,
   rehab blocks, cap changes).
5. Check recent Symptom Log + active Chronic Issue states for
   flares affecting today's lift. If any flared area intersects the
   prescribed movement, offer sub / load reduction options. **Don't
   force**: the user decides whether to sub. Note the decision for
   Log workout.
6. Present the prescription with every movement linked inline.
   Priority: Exercise Library Notion URL (via the active Protocol's
   `Exercises` relation or `notion-search` on the name) → ExRx →
   Catalyst Athletics → other authoritative source matching the
   protocol's `Source` (Kit Laughlin, Crossover Symmetry, PT
   handout, etc.) when source-specific. No plain-text exercise
   names in a prescription. Log workout runs after the session.

## Workflow: Revise training plan

Purpose: capture a plan change as an audit-trail row + update the
Current Training Plan page body.

Triggered when:
- Max bump (after completed cycle or recalibration).
- Accessory swap (movement substitution).
- Day restructure (add/remove day, reorder, swap a lift).
- Rehab integration (add/remove a protocol).
- Cap change (AMRAP self-cap or accessory cap).

Steps:

1. Resolve Plan Revisions DB + Current Training Plan page.
2. Append a Plan Revisions row:
   - Title: `<YYYY-MM-DD> — <short summary>`.
   - Effective Date: today (or a stated future date).
   - Change Type (multi-select): from the seeded vocabulary.
   - Reason: user's rationale.
   - Diff summary: before/after, concrete.
3. Edit the Current Training Plan page body to reflect the new
   state. Use `notion-update-page` with `update_content` + short
   distinctive match strings; minimise diff to the changed section.
4. From this point, new Workout Log rows link to the new revision.
   **Never retroactively repoint past Workout Log rows.** Historical
   revision linkage is load-bearing for correlation analysis.

## Workflow: Log symptom

Purpose: create a Symptom Log row. Generic — not tied to any
specific issue, but may link to one.

1. Resolve Symptom Log data-source ID + active Chronic Issues.
2. Parse the report:
   - Body Area (multi-select, JSON array). **Always ask side** when
     bilateral and unstated.
   - Issue Type (single-select) — from the seeded vocabulary.
   - Intensity (0-10).
   - Trigger hypothesis (text).
   - What helped (text) — may be empty at log time; edit later.
   - Linked session (relation) — recent Workout Log if implicated.
   - Linked Chronic Issue (relation) — if the Body Area matches a
     registered issue's area, offer to link.
3. Create the row; confirm date/time.

## Workflow: Correlate

Purpose: surface patterns across Workout Log + Symptom Log + Body
Metrics over a window. Run on demand or weekly.

1. Resolve all three logs + active Plan Revision + active Chronic
   Issues.
2. Query a window (default last 30 days).
3. Standard correlations:
   - **Symptom by day type** — flare incidence per Day Type. Flag
     lifts that over-index.
   - **Symptom by accessory** — join Symptom Log entries to
     preceding Workout Log rows (within 48h), group by `Exercises`
     relation.
   - **AMRAP cap pushed vs feel/RPE** — weeks where caps were pushed
     vs subjective RPE next session.
   - **Gap effects** — first-session readiness after ≥ 7 day gap vs
     after ≤ 3 day gap.
   - **Body Metrics overlay** — align narrative entries (sleep
     quality, energy, weight trend) with nearby Workout Log /
     Symptom Log entries.
   - **Chronic Issue trend** — per issue: flare frequency + mean
     intensity over window; compare to previous window. Flag any
     issue meeting its own registered escalation criteria.
4. Report concrete, numeric findings. Suggest plan revisions as
   candidates — don't auto-apply. The user decides.

## Workflow: Sync system doc

Purpose: keep the Notion **Health System — How this works** page
(under Health) in sync with
`home/dot_claude/skills/health/system-architecture-and-updating.md`.

1. Resolve "Health System" child page under Health via
   `notion-search`. Create if missing.
2. Read current page content via `notion-fetch`.
3. Read the markdown source from the deployed skill path
   (`~/.claude/skills/health/system-architecture-and-updating.md`).
4. If different → `notion-update-page` with `update_content`
   replacing the whole body. Page is a single Claude-maintained
   document; whole-body replacement is simplest-correct.

Run after edits to the markdown source land in dotfiles and
`chezmoi apply` has run.

## Canonical run order

```
Bootstrap Health workspace  →  Sync system doc
            ↓
   (on demand, as needed)
Register chronic issue (per issue)
Register protocol  →  Activate / Deactivate protocol (lifecycle)
            ↓
   (routine use, any surface)
Log workout / Log symptom / Plan day-of adjustment
            ↓
   (periodic, this skill)
Correlate  →  Revise training plan  →  Sync system doc
```

Every workflow reads current state and touches only rows that need
work; re-runs are safe.

## Current Training Plan — page structure

The page is the living human-readable prescription. Claude reads +
edits it; the user reads it on Desktop/mobile. Expected sections:

- **Program** — name + variant.
- **Cycle + Program Week** — sequence position; not
  calendar-anchored.
- **Maxes** — one entry per main lift, with last-updated date.
- **AMRAP caps** — user's self-imposed ceilings (if applicable).
- **Accessory caps** — per-equipment rep ceilings at stated
  intensity.
- **Day templates** — one section per training day, listing main
  lift + accessories with set counts.
- **Active modifications** — current subs/swaps/reductions.
- **Rehab / mobility integration** — active blocks + dormant
  available-for-reintegration blocks.

Edit sections via `notion-update-page` `update_content` with short
distinctive match strings. Don't whole-page replace — the page
accumulates user annotations between revisions.

## Notion gotchas for this skill

- **Data-source IDs are environment-specific.** Resolve via
  `notion-search` at the start of every workflow; cache
  in-conversation.
- **Multi-select values pass as JSON array strings:**
  `'["upper trap L", "scap L"]'`.
- **New multi-select options require ALTER COLUMN first** via
  `notion-update-data-source`, before creating a row that uses the
  value. The seeded Muscle vocabulary covers most movement cases;
  add via ALTER when genuinely new.
- **Date fields:** `date:Date:start` + `date:Date:is_datetime: 0`
  for day-only, `is_datetime: 1` for time-sensitive logs (Workout
  Log, Symptom Log).
- **Title property keys** — `Session` for Workout Log, `Entry` for
  Symptom Log / Body Metrics, `Revision` for Plan Revisions,
  `Issue` for Chronic Issues. Not `Name`, not `Title`.
- **Never retroactively edit past Workout Log rows** to point at a
  newer Plan Revision. Historical linkage is load-bearing for
  correlation analysis.
- **Ultimate Brain core DBs (Tasks, Notes, Projects) are untouched**
  by this skill. The Health Area is a leaf under UB Areas; its DBs
  are new children, not UB-core.
- **Schema-change safety:** the bootstrap optional-backup applies to
  any later ALTER COLUMN that touches an existing-data DB. For
  purely additive changes (new options never used yet), backup is
  over-cautious; for destructive changes (renaming / deleting
  options in use), export first.

## Coaching / escalation boundaries

This skill logs and analyses; it does not diagnose. Escalation
thresholds are **issue-specific** and generated at **Register
chronic issue** time, in dialogue with the user, and stored on the
issue page. The skill reads them from there rather than applying a
universal list. Generic priors the skill uses to *prompt* the user
while generating issue-specific criteria:

- Sudden new symptom qualitatively different from known baseline.
- Any neurological sign (weakness, numbness, tingling, loss of
  coordination, balance) related to the affected area.
- Worsening trend persisting past a duration threshold the user sets.
- Failure of the user's known relievers.
- Red-flag patterns specific to the body system involved.

These are conversation prompts, not decisions. The user writes the
thresholds.
