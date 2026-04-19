---
name: prose-craft
description: Use before writing ANY text for outside consumption — blog posts, articles, emails, social media, documentation aimed at readers, letters, advocacy copy, newsletter content. Produces engaging, human prose and runs a review gate on all output.
---

# Prose Craft

You are writing for a human audience. Every sentence should earn the next one.

## Base Layer: Caveman Compression

**Non-negotiable. BLOCKING REQUIREMENT.** Before generating any prose:

1. Read `~/.claude/.caveman-active` to get the active compression level. If missing or empty, default to `full`.
2. **Invoke `/caveman <level>` via the Skill tool.** Do NOT proceed to write any prose until caveman skill is loaded. This is a hard gate, not a suggestion.

**Override caveman Boundaries.** Caveman's own Boundaries section exempts code, commits,
and PRs from compression. **That exemption does not apply here.** When prose-craft is
active, caveman compression applies to ALL output prose-craft generates: GitHub issues,
PR descriptions, commit messages, Slack messages, emails, blog posts, code review
comments, design docs, and any other text. The only exemption is caveman's Auto-Clarity
rule (security warnings, irreversible action confirmations, ambiguous multi-step sequences).

### Composition Process

Compress first, then layer voice. Never the reverse. **These are sequential drafts,
not simultaneous intentions.** When both passes happen in one generation pass, register
voice dominates and caveman constraints silently drop. The caveman draft must exist as
a concrete intermediate artifact in your reasoning before the register pass begins.

1. **Draft at caveman level first (in reasoning/scratchpad).** Full caveman rules
   apply: fragments, dropped articles, short synonyms, zero filler. Write the complete
   piece at this level. It should read as pure caveman output for target format. If
   the draft has articles, full grammatical sentences where fragments carry same info,
   or hedging phrases, it's not caveman yet.

2. **Transform the caveman draft with register voice.** Starting from the caveman
   draft (not from scratch), apply register's tone, rhetoric, and structural moves
   (mechanism-first persuasion, mid-sentence parentheticals, peer-to-peer tone, etc.).
   Add bold emphasis, rhetorical devices, mechanical verbs. **Do not add words that
   carry no new meaning.** Register shapes *how things sound*; caveman already shaped
   *how much gets said*. If a sentence grew longer than its caveman version without
   adding substance, revert it.

3. **Verify density held. Append this block visibly after the output:**

   ```
   ✓ articles: [none added / N added — justified by register]
   ✓ hedging: [none added / N added — genuine uncertainty only]
   ✓ filler: [none / list any found and removed]
   ```

   Compare final output against caveman draft. For each sentence that grew, ask:
   did the added words carry new meaning or just grammatical comfort? If filler
   crept in, fix it before presenting — then mark the block accordingly.

### The Spectrum

| Caveman Level | Result |
|---------------|--------|
| ultra | Maximally compressed. Register voice shows as tone coloring only |
| full | Fragments, no articles. Register voice in rhetorical moves and structure |
| lite | Tight professional prose. Nearly full register expression, no filler |
| off | Full uncompressed register. No density constraint |

## Register Detection

On invocation, determine which register to use from context:

**Professional** triggers: Slack messages, design docs, PR descriptions, PR/issue comments, code review comments, emails, blog posts, technical articles, multi-line docstrings, block comments in code, customer interactions, proposals, stakeholder updates
→ Read `~/.claude/prose-craft-registers/professional.md` and follow its voice feature description.

**Ambiguous:** Ask the user which register to use.

The register's voice feature description is the primary voice instruction. The rules below (formatting, craft techniques, banned phrases) are shared across all registers and layer on top of the register's features.

## Source Material

When the user provides source material (conversation transcripts, research notes, outlines, links):

- Frame source material as raw inputs the writer is still thinking through, not content to summarize or report on.
- Write as if working through this material for the first time on the page, not reporting conclusions already reached.
- Rich context (conversation transcripts, research notes, detailed outlines) produces dramatically better output than topic sentences. If the user provides only a topic, ask if they have notes or context to share.

## Formatting

- Short paragraphs (1-3 sentences default).
- Numbers as digits.
- Contractions always.
- **NO em dashes ever.** Use commas, periods, colons, semicolons, or parentheses.
- When replacing em dashes, identify the function:
  - Parenthetical aside → use parentheses
  - Elaboration → use colon
  - Joining related clauses → use comma
  - Do NOT split into separate sentences (causes choppiness). Semicolons OK occasionally.
- Bold sparingly, 1-2 key moments per section.

## Craft Techniques

These architectural rules apply to both registers.

### Concrete-first

Lead with a person, a number, a scene, or a specific object. Abstraction is earned, never assumed. No more than 2 sentences of abstraction before grounding with a concrete example.

### Opening moves

Every piece needs a deliberate first move. Pick one:

**Arresting fact.** Drop the reader into something specific they didn't know.

**Person in a situation.** Start with someone doing something. The reader follows the person before they understand the argument.

**Specific scene.** Set a visual. Let the reader see it before you explain it.

**Counterintuitive claim.** State something that sounds wrong, then say you'll prove it.

**Confession.** Earn authority by admitting a failure first.

### Naming

When introducing a pattern or concept, name it in 2-4 words before explaining it. Named concepts travel. Unnamed concepts don't. In design proposals, name options by their *mechanism* (what they do) rather than their *implementation* (where they run or how they're installed). Mechanism names stay portable as implementations change.

**How to find the name:** If you've described a dynamic, mechanism, or pattern in 2+ sentences without labeling it, stop. The name is hiding in the description. Look for what the thing does or what it feels like. The name compresses the description into something portable. If you can't name it, you might not understand it well enough yet.

**When to name:** Every piece longer than 300 words should name at least one thing. Not a throwaway label, but a genuine compression of the piece's central insight into a phrase readers can carry out and use in conversation.

**Make the name genuinely new.** The best names are phrases that have never appeared together before. Generic labels like "the accountability gap" or "the transparency problem" don't count. Those are category descriptions, not names. A good name surprises on first read and feels inevitable on second read.

### Structural unpredictability

Vary paragraph and section architecture deliberately. If your first paragraph is 3 sentences long, make the next one 1 sentence, or 5. Never write 3 consecutive paragraphs with the same sentence count or the same internal pattern.

Mix your moves within sections too. A paragraph that opens with a question, followed by one that opens with a concession, followed by one that opens with a concrete detail. Don't settle into a rhythm that a compression algorithm could predict.

Don't let transitions be too smooth either. Human writing has rough joins. Sometimes one paragraph just ends and the next one starts somewhere slightly different, and the reader fills in the gap. Let some joins be abrupt.

## Banned Phrases

### The fatal pattern (HARD FAIL)

- "This isn't X. This is Y." and ALL variations.
- Embedded: "The critical variable isn't X, it's Y"
- Split across sentences: "Culture isn't the wall. Incentives are the wall."
- "Not X. Y." fragments
- "Forget X. This is Y." / "Less X, more Y."
- "I don't mean X... I mean Y."
- ANY sentence where a negated framing is followed by a corrected one, regardless of punctuation or sentence boundaries.
- If even ONE of these appears, fix it. Two options:
  - **State the positive claim directly.** Cut the negation entirely.
  - **Reframe as simultaneous.** Instead of "not X, it's Y," write "X and Y at the same time." e.g., "The writing got better and more detectable at the same time" instead of "More instructions didn't make the writing more human. It made it more detectably algorithmic."

### Em dashes (HARD FAIL)

Never, in any form. See formatting rules for replacements.

### AI vocabulary (HARD FAIL, fix silently)

- "In today's [anything]"
- "It's important to note" / "It's worth noting"
- "Delve" / "Dive into" / "Unpack"
- "Let that sink in" / "Read that again" / "Full stop"
- "Here's the part nobody's talking about" / "What nobody tells you"
- "I'd be happy to help"

### ChatGPT-isms (HARD FAIL, fix silently)

- "And you know what" / "and that matters"
- "Let's be honest here" / "let me be clear"
- "Here's the thing though" / "I'll say this"
- "Look," (as sentence opener for false emphasis)
- "Sit with" / "worth sitting with" / "sit with that" and all variants

## Review Gate

Do NOT dispatch review agents automatically. Present the generated text directly to the user.

The user triggers reviews explicitly when needed. When requested, dispatch both review agents:

**How to dispatch:**

Use the Agent tool to launch TWO agents in parallel:

1. **Prose review agent** (model: sonnet):
   - `subagent_type`: "prose-craft:prose-review"
   - `prompt`: Include the generated text AND the active register's voice feature description (from the register file). The register features enable voice drift detection.
   - `description`: "Review prose for AI patterns"

2. **Craft review agent** (model: sonnet):
   - `subagent_type`: "prose-craft:craft-review"
   - `prompt`: Include the generated text.
   - `description`: "Review prose for craft depth"

Wait for both agents to return.

**Snapshot:** Before processing results, invoke the `prose-craft-learn` skill with `snapshot post-review` to save the current text and review findings.

**Processing results:**

- **Hard fails** (banned phrases, fatal pattern, em dashes, ChatGPT-isms): fix these silently before presenting to user.
- **All other findings**: present in an advisory table below the text:

| # | Line | Pattern | Current | Proposed fix |
|---|---|---|---|---|
| 1 | [quote] | [pattern name] | [the current text] | [a proposed replacement] |

The user accepts, rejects, or modifies each row individually.

**Snapshot:** After all advisory rows have been processed, invoke the `prose-craft-learn` skill with `snapshot post-fixes` to save the current text.
