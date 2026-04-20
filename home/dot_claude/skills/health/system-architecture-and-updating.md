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
| Reference link | URL | ExRx preferred; Catalyst fallback |
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
| Linked Chronic Issue | Relation → Chronic Issues | Optional; auto-suggested when Body Area matches a registered issue |

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
| Correlate logs | `health` skill | Claude Code CLI (laptop) |
| Revise training plan | `health` skill + Health Project Custom Instructions | Either; CLI recommended for rich diffs |
| Sync this doc → Notion | `health` skill's Sync workflow | Claude Code CLI |
| Per-issue escalation criteria | Generated at Register time; stored on the issue page | Read by all surfaces at runtime |

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
