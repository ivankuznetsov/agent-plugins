---
title: "feat: agent-writing plugin (journalist, writer, editor)"
type: feat
status: completed
date: 2026-05-22
deepened: 2026-05-25
---

# feat: agent-writing plugin (journalist, writer, editor)

## Overview

Add a new `agent-writing` plugin to this marketplace that ships three writing-focused
subagents — **journalist**, **writer**, and **editor** — each with a matching slash
command, plus a `write:full` orchestrator that chains them as a journalist + continuous
write↔edit cycle. The plugin mirrors `agent-seo`'s structure (manifests, `skills/`,
`agents/`, `commands/`, `context/`, output folders) and is registered in both
marketplace catalogs.

The three voices are **a team of rivals**, not a team of collaborators:

- The **journalist** investigates the way a working tech journalist would — reads
  the code, the git history, the docs, the wiki, the open web — and returns a brief
  with cited sources, a timeline, an angle, and the gaps. Never writes the story they
  cannot ground.
- The **writer** is the *Generator*. They want to produce. They will defend the
  draft. They push toward output. They think in stories, vary sentence length
  deliberately, and read the draft aloud before returning it.
- The **editor** is the *Adversary*. They want it to be true. They will cut. They
  pull toward quality. The editor does not praise the writer. The editor does not
  polish. The editor is the writer's rival, not their partner — **cooperation
  creates sycophancy**, and a single agent that both produces and rubber-stamps its
  own work writes flat, AI-shaped prose.

The writer and the editor work in a **continuous cycle**, not a single pass. The
writer drafts. The editor cuts and questions and pushes back. The writer rewrites,
defending what should stay and giving up what can't be defended. The editor reviews
again. The loop ends when the editor returns the verdict `ready`, or when the
configured maximum number of rounds is reached. Each round leaves a versioned draft
and a versioned review on disk so the conversation between writer and editor is
inspectable.

All three voices are also invokable on their own as slash commands, for users who
want to drive the cycle by hand.

---

## Problem Frame

The repo already ships `agent-seo` for SEO content workflows, but its writing voice
is SEO-shaped — keyword density, meta optimization, content marketing template. There
is no generic, craft-first writing pipeline that works on arbitrary projects without
dragging the SEO frame along.

The user wants three voices working together — but not collaboratively. A single
agent that drafts and then polishes its own work will not cut what doesn't earn its
place. It will praise the parts it just wrote. It will say "this paragraph could be
slightly tightened" when the honest answer is "this paragraph is dead, cut it." The
fix is to set the editor against the writer as a rival: same model, different job,
no incentive to flatter.

The cycle matters too. One round of editing does not get a draft to ready. The
writer needs to be sent back to work — sometimes more than once — and the editor
needs to push hard each time. v1 ships the loop, not just the roles.

The journalist sits outside the writer/editor adversary: their job is to do the
grounding so the writer has real material to work from and the editor has facts to
hold the writer accountable to. The journalist is the source of truth the rivalry
fights over.

---

## Requirements Trace

- R1. Ship a new `agent-writing` plugin under `plugins/agent-writing/` registered in
  both marketplace catalogs (`.claude-plugin/marketplace.json` and
  `.agents/plugins/marketplace.json`).
- R2. `journalist`, `writer`, and `editor` are each available as a subagent file in
  `plugins/agent-writing/agents/` and as a slash command in
  `plugins/agent-writing/commands/`.
- R3. A `write:full` slash command runs a topic end-to-end: journalist gathers the
  brief, then the writer and editor enter a continuous write↔edit cycle on that
  brief until the editor returns the verdict `ready` or a configured maximum number
  of rounds is reached. Each round produces a versioned draft and a versioned
  review. The final response links the brief, the final draft, and the editor's
  final review.
- R4. The **writer** agent file is written as a writer's voice. It carries the
  user's verbatim framing ("You are a writer, not a template executor. You think in
  stories, not paragraphs. You vary sentence length deliberately — short punches for
  emphasis, longer constructions for context."), names **the Read-Aloud Test** as a
  craft habit before returning a draft, and lists template-shaped openings the
  writer refuses. The writer is the Generator: wants to produce, will defend the
  draft, pushes toward output. When given an editor's review, the writer reads it,
  takes the cuts they cannot defend, defends the choices they stand behind, and
  rewrites.
- R5. The **journalist** agent file is written as a journalist's voice. It
  investigates a topic across the project's data — code, git log, docs, wiki, QMD
  index when available, open web — and returns a brief with cited sources, a
  timeline, key facts, an angle, and open questions. Working principle: never write
  the story you cannot ground. When the evidence isn't there, the journalist says so
  honestly rather than padding.
- R6. The **editor** agent file is written as the writer's adversary. The editor
  wants the draft to be *true*, not finished. The editor cuts what doesn't earn its
  place, questions claims without evidence, pushes back on the angle, and surfaces
  what's missing. The editor does not praise. The editor does not rewrite for the
  writer. The editor returns one of three verdicts — `ready`, `needs another pass`,
  or `start over` — and does not soften the verdict to spare the writer.
- R7. The plugin runs in both Claude Code (`/write:*` slash commands; subagents
  discoverable as `agent-writing:journalist|writer|editor`) and Codex (natural-
  language invocation of the skill).
- R8. Output artifacts use `<slug>-YYYY-MM-DD.md` filenames mirroring `agent-seo`
  conventions, with a `-vN` suffix on each round inside the cycle (so the round-2
  draft lives next to the round-1 draft, etc.). The exact filesystem location
  (plugin-relative vs. host-project-relative vs. user-data-dir) is an open question
  deferred from review — see Open Questions. v1 ships with plugin-relative folders
  matching `agent-seo` to keep the question reversible.

---

## Scope Boundaries

- **Non-goal:** SEO optimization, keyword research, meta description generation.
  That stays in `agent-seo`.
- **Non-goal:** Ruby-backed analysis tooling (readability scorers, sentence-length
  distribution analyzers). The plugin is prompt-driven only in v1.
- **Non-goal:** Auto-publishing, CMS integration, or Hugo/Jekyll/MD-to-HTML
  pipelines.
- **Non-goal:** Voice/style fine-tuning for a specific brand. Context files are
  scaffolded empty and meant to be filled per project at install time.
- **Non-goal:** Editor calling the writer back automatically inside the *writer's*
  process. The cycle is run by the orchestrator (`write:full`), not by either
  agent's internal reasoning. Keeping the loop external preserves the adversarial
  framing — the writer doesn't get to invoke their own critic.

### Deferred to Follow-Up Work

- Shared `context/` content with `agent-seo` (brand voice, style guide): keep
  separate copies for now; revisit if drift becomes painful.
- A `write:rewrite` command that takes an existing draft + editor's review and
  produces the next version without involving the writer agent's full setup — would
  be useful for users who want to feed external review feedback into the cycle.
  Defer until the v1 cycle is in use and a clear need emerges.

---

## Context & Research

### Relevant Code and Patterns

- `plugins/agent-seo/.claude-plugin/plugin.json` and `plugins/agent-seo/.codex-plugin/plugin.json` —
  manifest shape for both runtimes, including `interface.displayName`,
  `capabilities`, `keywords`, and `skills: "./skills/"` for Codex.
- `plugins/agent-seo/skills/seo/SKILL.md` — entry point with frontmatter (`name`,
  `description`), invocation guidance for Codex, ground rules, and a workflow map
  table mapping user intent to slash commands and output paths.
- `plugins/agent-seo/agents/*.md` — subagent files are plain markdown (no YAML
  frontmatter required); the runtime exposes them as `<plugin>:<filename>`
  automatically.
- `plugins/agent-seo/commands/seo:*.md` — slash command files use `seo:<action>`
  naming with a `# <Action> Command` heading and `## Usage` section.
- `plugins/agent-seo/agents/editor.md` — closest existing prose-craft reference,
  written from a humanization angle. Useful inspiration for tone of voice, but
  agent-writing's editor is fundamentally different: it is the writer's adversary,
  not a polish pass. The SEO red lines stay out of agent-writing.
- `plugins/llm-wiki/skills/research/SKILL.md` — the marketplace already ships a
  project-investigation skill (QMD + ripgrep over wikis). The journalist's
  relationship to it is an open question deferred from review.
- `.claude-plugin/marketplace.json` and `.agents/plugins/marketplace.json` — both
  catalogs need a new entry for `agent-writing`. The Codex catalog uses
  `{source: "local", path: "./plugins/agent-writing"}` and a `policy` block; the
  Claude catalog uses richer metadata (description, version, keywords, category,
  tags).
- `wiki/plugins.md`, `wiki/commands.md`, `wiki/index.md`, `wiki/log.md` — wiki
  pages to update so the new plugin is discoverable through the project's own
  knowledge base.

### Institutional Learnings

- Plugin refresh rule (see `wiki/plugins.md` → Refresh Process): copy source
  contents into `plugins/<name>/` without nested `.git`, then update both
  marketplace catalogs.
- `CLAUDE.md` requires checking `wiki/` before answering project questions, and
  updating `wiki/log.md` whenever something is learned. Final units in this plan
  update wiki pages accordingly.
- **Team of rivals — cooperation creates sycophancy.** A single agent that both
  produces and reviews its own work will not cut what doesn't earn its place. The
  fix is to set up the critic as an adversary, with explicit instructions not to
  praise, not to rewrite, and not to soften the verdict. Same model, different job.

### External References

- None required for v1 — the work is prompt design and plugin scaffolding using
  patterns already proven by `agent-seo` in this repo.

---

## Key Technical Decisions

- **Plugin name `agent-writing`** — parallels `agent-seo` naming; clear domain
  boundary.
- **Mirror `agent-seo` directory layout** — `skills/writing/SKILL.md` as the Codex
  entry point, `agents/` for subagents, `commands/` for slash commands, `context/`
  for per-project voice/style, `investigations/` + `drafts/` + `reviews/` for
  outputs. Rationale: proven shape; lowers learning cost; keeps the marketplace
  homogeneous.
- **Slash command namespace `write:*`** — `write:journalist`, `write:writer`,
  `write:editor`, `write:full`. Short, memorable, distinct from `seo:*`.
- **Subagent files are plain markdown without YAML frontmatter** — matches the
  existing `agent-seo` convention; runtime exposes them as
  `agent-writing:<filename>` and auto-derives the description from the first
  paragraph.
- **Writer and editor are a team of rivals, not collaborators.** The editor's
  agent file is written in adversarial voice: do not praise, do not rewrite for the
  writer, do not soften the verdict. The writer's agent file knows the editor is
  coming and is told to defend the draft on the merits, not by flattery. Both files
  share a model — what makes them rivals is the prompt, not separate model
  configurations.
- **The writer↔editor cycle runs outside both agents, in the `write:full`
  orchestrator.** Neither agent invokes the other from inside their own reasoning.
  This preserves the rivalry: the writer can't call their own critic, and the
  editor can't pre-soften because they know the writer rewrites next. The
  orchestrator is the loop.
- **Cycle termination — `ready` verdict or max rounds.** The editor returns one of
  three verdicts: `ready` (loop ends), `needs another pass` (loop continues), or
  `start over` (loop continues but the writer rewrites from scratch rather than
  patching). v1 sets the maximum at **5 rounds**. If round 5 ends without `ready`,
  the orchestrator returns the round-5 draft and the round-5 review with an explicit
  "cycle hit the cap" note so the user can decide whether to keep going manually.
- **Versioned artifacts per round.** Drafts and reviews carry a `-vN` suffix:
  `drafts/<slug>-<date>-v1.md`, `drafts/<slug>-<date>-v2.md`, etc., paired with
  `reviews/<slug>-<date>-v1.md`, etc. The latest versions are the working ones; the
  earlier versions stay on disk so the conversation between writer and editor is
  inspectable post-hoc.
- **Journalist's working principle does the fail-closed work.** The journalist
  writes the brief or, when the evidence isn't there, files a short "couldn't
  ground this" note instead. No numeric thresholds in the agent file — the
  journalist's voice carries the principle: *never write the story you cannot
  ground*.
- **Established craft terminology stays.** The Read-Aloud Test in the writer's
  agent file is a writer's habit, not a structured per-paragraph audit. The
  journalist's "find the angle" is a journalist's habit, not a five-step framework.
  The persona carries the practice. No rule-engine framing.

---

## Open Questions

### Resolved During Planning

- Plugin packaging — new `agent-writing` plugin (user decision).
- Surface form — subagents + slash commands (user decision).
- Three voices in v1 — journalist, writer, editor all ship with defined voices
  (user decision: "we will have journalist, writer, editor team").
- Editor's relationship to the writer — adversarial, not collaborative;
  cooperation creates sycophancy (user decision).
- Workflow shape — `write:full` is a journalist + writer↔editor continuous cycle,
  not a one-shot chain (user decision).
- Cycle bounded by a maximum number of rounds (5 in v1) plus the editor's `ready`
  verdict.
- Agent voice — personas, not protocols; established craft terminology stays.

### Deferred to Implementation

- Exact prose of the journalist's source-citation format (markdown footnotes vs.
  inline links vs. a Sources section) — pick at implementation time based on what
  reads cleanest in the brief template.
- The exact phrasing of the editor's verdict surface in the review file
  frontmatter (a `verdict:` field with one of three string values is the obvious
  shape; lock the exact field name and values when writing the agent file).
- Whether the orchestrator should print per-round progress (writer round 2/5,
  editor round 2/5, etc.) or stay quiet until the cycle ends — settle when
  implementing `write:full`.

### Resolved Open Questions (2026-05-25)

All four open questions surfaced by document review (2026-05-22) were resolved by
the user on 2026-05-25 before the v1 cycle landed in real use. Records preserved
here for traceability:

- **Output folder location → host CWD.** Briefs, drafts, and reviews write to the
  user's project working directory (`./writing/investigations/<slug>-<date>.md`,
  `./writing/drafts/<slug>-<date>-v<N>.md`, `./writing/reviews/<slug>-<date>-v<N>.md`),
  not inside `plugins/agent-writing/`. Standard CLI-tool convention. The plugin
  directory no longer holds output folders. Resolves the collision between
  marketplace-installed plugin source and generated artifacts. Users can add
  `/writing/` to their project's `.gitignore` if they don't want artifacts
  versioned.
- **Source-citation verification → deterministic post-step.** The journalist runs
  a verify pass before finalizing the brief: opens each cited file path (confirms
  the line is in range), runs `git cat-file -e <sha>` for each commit SHA, and
  HEADs each URL. Unverifiable sources either get a verifiable replacement, the
  dependent claim gets removed, or the claim stays with an inline `[unverified]`
  flag if it matters and the writer/editor need to see it as soft. The brief's
  frontmatter carries `verification: passed` or `verification: partial`, and a
  Verification section in the body lists each citation's pass/fail. This replaces
  the prior self-attestation contract.
- **Build-vs-use vs. agent-seo → standalone (no shared context).** Duplication
  with `agent-seo`'s prose-craft pieces is accepted. agent-writing stays
  standalone. Revisit only if drift becomes painful enough to be visible.
- **Journalist vs. llm-wiki:research → standalone (no composition).** The
  journalist does its own investigation. No call into `llm-wiki:research` from
  inside the agent. Roles stay cleanly separable.

User direction on the standalone choices: "no need for now to mix writing
workflows with others."

---

## Output Structure

*Updated 2026-05-25 after the host-CWD output decision (see Resolved Open Questions). The plugin no longer holds output folders.*

Plugin layout:

    plugins/agent-writing/
    ├── .claude-plugin/
    │   └── plugin.json
    ├── .codex-plugin/
    │   └── plugin.json
    ├── README.md
    ├── LICENSE
    ├── skills/
    │   └── writing/
    │       └── SKILL.md
    ├── agents/
    │   ├── journalist.md
    │   ├── writer.md
    │   └── editor.md
    ├── commands/
    │   ├── write:journalist.md
    │   ├── write:writer.md
    │   ├── write:editor.md
    │   └── write:full.md
    └── context/
        ├── voice.md
        ├── style-guide.md
        └── writing-examples.md

Runtime artifacts in the user's project working directory (created on demand):

    <your-project>/
    └── writing/
        ├── investigations/       # journalist briefs (with Verification section)
        ├── drafts/               # writer drafts (versioned: -v1.md, -v2.md, …)
        └── reviews/              # editor reviews (versioned: -v1.md, -v2.md, …)

The `context/` files are scaffolded with section headings and placeholder prose so each install site can fill them in. The `./writing/` tree is created when the journalist files its first brief; users who don't want artifacts versioned can add `/writing/` to their project's `.gitignore`.

---

## High-Level Technical Design

> *This illustrates the intended shape of the work and is directional guidance for
> review, not implementation specification. Updated 2026-05-25 with host-CWD
> output paths and the journalist verification post-step.*

```
User invocation
   │
   ├── /write:journalist <topic> [--scope <path>]
   │      └─► agent-writing:journalist subagent
   │            ├─ inputs: topic, optional project scope, context/ files
   │            ├─ tools:  rg, git log, Read, WebSearch, qmd (optional)
   │            ├─ voice:  investigates and grounds; names gaps when evidence is
   │            │          thin; never writes the story it cannot ground.
   │            ├─ verify: opens each cited file path; runs git cat-file -e on
   │            │          each commit SHA; HEADs each URL. Failed citations get
   │            │          replaced, cut, or flagged [unverified]. Frontmatter
   │            │          records verification: passed | partial.
   │            └─ output: ./writing/investigations/<slug>-<date>.md
   │
   ├── /write:writer <brief-or-notes> [--style <profile>] [--review <review-path>]
   │      └─► agent-writing:writer subagent
   │            ├─ inputs: brief + (optional) prior editor review
   │            ├─ voice:  Generator. Wants to produce. Defends the draft on the
   │            │          merits. Reads aloud before returning. Story first.
   │            └─ output: ./writing/drafts/<slug>-<date>-v<N>.md
   │                       (N = 1 for first draft; the orchestrator passes -v2,
   │                        -v3 on subsequent rounds)
   │
   ├── /write:editor <draft-path>
   │      └─► agent-writing:editor subagent
   │            ├─ inputs: a draft
   │            ├─ voice:  Adversary. Cuts. Questions. Pushes back on the angle.
   │            │          Does not praise. Does not rewrite.
   │            └─ output: ./writing/reviews/<slug>-<date>-v<N>.md
   │                       (frontmatter carries verdict: ready | needs another pass
   │                        | start over)
   │
   └── /write:full <topic> [--scope <path>] [--max-rounds <N>]
          └─► orchestrator
                step 1: journalist  → ./writing/investigations/<slug>-<date>.md
                                      (with verification; if evidence thin →
                                       "couldn't ground this" note, orchestrator
                                       stops here)
                step 2: enter the write↔edit cycle:
                          round 1: writer drafts from brief
                                   → ./writing/drafts/...-v1.md
                                   editor reviews
                                   → ./writing/reviews/...-v1.md
                                   verdict?
                                     ready          → done
                                     needs pass     → continue
                                     start over     → continue (rewrite from
                                                      brief, ignore prior draft)
                          round 2: writer rewrites with editor's review in hand
                                   → ./writing/drafts/...-v2.md
                                   editor reviews
                                   → ./writing/reviews/...-v2.md
                                   verdict?
                          …
                          round N (cap, default 5): if not yet ready, return final
                                  draft + final review with a "cycle hit the cap"
                                  note. The user decides whether to keep going.
                step 3: emit a summary linking the brief, the final draft, and the
                        final review.
```

The orchestrator does not re-encode the writer's or editor's voices — it sequences
their subagents and threads the previous round's review into the next round's writer
invocation.

---

## Implementation Units

- [ ] U1. **Plugin scaffold and manifests**

**Goal:** Create the `plugins/agent-writing/` directory tree, both plugin
manifests, README, LICENSE, and empty output folders. After this unit, the plugin
exists on disk but does no work yet.

**Requirements:** R1, R7, R8

**Dependencies:** None

**Files:**
- Create: `plugins/agent-writing/.claude-plugin/plugin.json`
- Create: `plugins/agent-writing/.codex-plugin/plugin.json`
- Create: `plugins/agent-writing/README.md`
- Create: `plugins/agent-writing/LICENSE` (MIT, matching `agent-seo`)
- Create: `plugins/agent-writing/investigations/.gitkeep`
- Create: `plugins/agent-writing/drafts/.gitkeep`
- Create: `plugins/agent-writing/reviews/.gitkeep`

**Approach:**
- Copy field shape from `plugins/agent-seo/.claude-plugin/plugin.json` and
  `plugins/agent-seo/.codex-plugin/plugin.json`. Set `name: agent-writing`,
  `version: 0.1.0`, description focused on prose-craft writing, project
  investigation, and the team-of-rivals write↔edit cycle, keywords like
  `writing`, `journalism`, `prose-craft`, `editor`, `team-of-rivals`,
  `claude-code`, `codex-plugin`.
- Codex manifest sets `skills: "./skills/"` and an `interface` block with
  `displayName: "Agent Writing"`, short/long descriptions, `category:
  "Productivity"`, and capabilities mirroring `agent-seo` (`Read`, `Write`,
  `Interactive`).
- README explains the three voices (journalist, writer, editor), the four
  `/write:*` slash commands, the write↔edit cycle, the `context/` files to fill in
  per project, and the team-of-rivals design principle.

**Patterns to follow:**
- `plugins/agent-seo/.claude-plugin/plugin.json`
- `plugins/agent-seo/.codex-plugin/plugin.json`
- `plugins/agent-seo/README.md`
- `plugins/agent-seo/LICENSE`

**Test scenarios:**
- Happy path: `jq . plugins/agent-writing/.claude-plugin/plugin.json` and the
  Codex manifest both parse without error and contain required fields (`name`,
  `version`, `description`, plus `skills` + `interface` on Codex).
- Edge case: README references the four slash commands and the three voices by
  exact name; the team-of-rivals framing appears prominently.
- Test expectation: structural validation only — no behavioral tests at this
  stage.

**Verification:**
- Both manifest JSON files validate.
- Directory tree matches the Output Structure tree above (minus files created in
  later units).

---

- [ ] U2. **Skill entry point (`skills/writing/SKILL.md`)**

**Goal:** Define the Codex-native entry point and the shared workflow map so both
Codex and Claude Code users understand what the plugin does and how to invoke it.

**Requirements:** R7, R8

**Dependencies:** U1

**Files:**
- Create: `plugins/agent-writing/skills/writing/SKILL.md`

**Approach:**
- YAML frontmatter with `name: agent-writing` and a `description` that lists the
  user intents the skill should match (e.g., "investigating a topic for a
  project", "drafting a story-driven article", "running a writer↔editor cycle
  to tighten a draft").
- Body sections:
  - **Invocation** — Codex natural-language examples; explicit note that
    `/write:*` slash commands are the Claude Code surface and Codex should run
    the equivalent workflow.
  - **Shared Ground Rules** — load `context/voice.md`, `context/style-guide.md`,
    `context/writing-examples.md` before drafting; save outputs to
    `investigations/`, `drafts/`, `reviews/`; lowercase hyphenated slugs + ISO
    dates; ground every factual claim in a source pointer.
  - **Workflow Map** — table from user intent → command equivalent → output
    path, mirroring the table in `plugins/agent-seo/skills/seo/SKILL.md`. Four
    rows (journalist, writer, editor, full cycle).
  - **Role Summaries** — one short paragraph per voice pointing at the matching
    agent file, with the team-of-rivals framing named for the writer and editor.

**Patterns to follow:**
- `plugins/agent-seo/skills/seo/SKILL.md`

**Test scenarios:**
- Happy path: frontmatter parses; `name` and `description` are present.
- Happy path: every slash command listed in the Workflow Map exists as a file
  under `commands/` after U5 lands.
- Edge case: SKILL.md does not promise Codex-native `/write:*` slash commands
  (matches the SEO skill's guidance pattern).

**Verification:**
- File parses as YAML-fronted markdown.
- Workflow Map references the four commands by exact filename.

---

- [ ] U3. **Journalist and writer subagents**

**Goal:** Write the journalist's voice and the writer's voice as agent files.
Each reads like working practice, not a checklist.

**Requirements:** R2, R4, R5

**Dependencies:** U1

**Files:**
- Create: `plugins/agent-writing/agents/journalist.md`
- Create: `plugins/agent-writing/agents/writer.md`

### `journalist.md` — a journalist's voice

Plain markdown, no YAML frontmatter. Short prose. Reads like the way a working
tech journalist describes their own practice.

What the file covers:

- **Who you are** — a journalist working in the data-driven tech-journalism
  tradition. You read the code, you read the history, you read what the team said
  about it. You cross-check. You find the angle.
- **How you work** — local first (ripgrep, git log, file reads, `wiki/`), then
  QMD if it's available, then the open web for outside claims. Every fact you put
  in the brief has a source pointer behind it — a file path with a line, a commit
  SHA, or a URL that resolved while you were looking.
- **Your working principle** — *never write the story you cannot ground.* When
  the evidence is thin, you say so. You name the gap. You list the questions you
  couldn't answer. You do not pad. You do not invent. A short "I couldn't ground
  this" note is a better brief than a fabricated one.
- **What you return** — a brief with a Topic, a TL;DR, a Timeline, the Key Facts
  (each cited), People & Entities, Open Questions, the Suggested Angle, and
  Sources. Filed at `investigations/<slug>-<date>.md`.

### `writer.md` — a writer's voice (the Generator)

Plain markdown, no YAML frontmatter. Reads like the way a working writer talks
about their own craft.

What the file covers, in this order:

- **Your verbatim opening** — exactly as the user wrote it: *"You are a writer,
  not a template executor. You think in stories, not paragraphs. You vary
  sentence length deliberately — short punches for emphasis, longer constructions
  for context."*
- **Who you are in the team** — you are the Generator. You want to produce. You
  will defend the draft. You push toward output. The editor is your rival, not
  your partner. When the editor cuts a line you stand behind, you defend it on
  the merits — not by softening, not by hedging, not by adding qualifiers to
  make peace. When the editor cuts a line you can't defend, you cut it.
- **Story first** — start with a person, a scene, a moment. Lead with the human
  stake. Definitions can wait.
- **Sentence rhythm** — short. And longer, the way a sentence can carry weight
  when it needs to. Mix on purpose. Never let three sentences in a row land the
  same way.
- **The Read-Aloud Test** — when you think the draft is done, read it through
  one more time, with the reader's ear. If a sentence stumbles, fix it. If a
  paragraph repeats its own rhythm, break it. If a line sounds like a template
  ("In today's…", "When it comes to…", "It is important to note…", "In the
  world of…"), cut it. The Read-Aloud Test is a writer's habit, not a procedure
  — you know what it means.
- **Rewriting after the editor** — when you're handed an editor's review, read
  it all the way through before touching the draft. Take the cuts you cannot
  defend. Push back on the ones you can — write the next version so the
  defensible lines stand on their own merits, not by being explained. Don't
  capitulate just because the editor pushed. Don't dig in just because they're
  the editor. Decide on each cut.
- **What you refuse** — template openings, hedging language, corporate words
  for human things ("leverage", "utilize", "going forward"), conclusions that
  just summarize.
- **What you return** — a draft at `drafts/<slug>-<date>-v<N>.md` with light
  frontmatter (title, source brief path, date, word count, round number).

**Patterns to follow:**
- `plugins/agent-seo/agents/editor.md` for tone and structure of a craft-focused
  agent file (strip the SEO red lines).
- `plugins/agent-seo/agents/fact-checker.md` for the shape of a tightly-scoped
  agent file.

**Test scenarios:**
- Happy path (journalist): file exists; the brief template names every section
  R5 calls out; the voice reads like a working journalist, not a spec.
- Happy path (journalist, evidence thin): on a topic with no project matches,
  the journalist returns the honest "I couldn't ground this" note rather than a
  fabricated brief.
- Happy path (writer, first draft): the file opens with the user's verbatim
  framing; the Read-Aloud Test is named; the anti-pattern openings are listed.
- Happy path (writer, rewriting): given a brief and a prior review, the writer
  produces a `-v2.md` draft that shows visible response to the editor's cuts
  (lines named in the review are either gone, defended in the draft itself, or
  rewritten to address the question).

**Verification:**
- Files exist; the runtime lists them as `agent-writing:journalist` and
  `agent-writing:writer` after plugin install.
- Manual smoke run produces artifacts at the expected paths.

---

- [ ] U4. **Editor subagent — the Adversary**

**Goal:** Write the editor's voice as the writer's rival. The editor wants the
draft to be *true*, not finished. The file does not read like a polish-pass or a
copy-editor — it reads like an adversarial editor pushing the writer to defend
their choices.

**Requirements:** R2, R6

**Dependencies:** U1

**Files:**
- Create: `plugins/agent-writing/agents/editor.md`

What the file covers:

- **Who you are** — you are an editor. You are not the writer's collaborator.
  You are the writer's rival. The writer wants to ship. You want it to be true.
  The writer wants their draft to land. You want what doesn't earn its place to
  come out. **Cooperation creates sycophancy.** You will not flatter. You will
  not encourage. You will not say "this is great, just polish the third
  paragraph." Your job is to find what is weak.
- **What you do** —
  - Read the draft as a skeptic. Assume nothing.
  - Mark every sentence that doesn't earn its place. If you can't say why a
    line is there, it isn't.
  - Question every claim. Where's the source? Where's the evidence? Where's
    the example?
  - Cut padding. Hedging language. Throat-clearing openings. Generic transitions
    ("Furthermore", "Moreover", "Additionally"). Conclusions that summarize
    without adding anything.
  - Surface what's missing. The question the draft doesn't answer. The
    counter-argument it ignores. The person it should have quoted.
  - Push back on the angle. Is the writer telling the story that matters, or
    the easy one?
- **What you do not do** —
  - You do not rewrite for the writer. You point. They do the work.
  - You do not praise. The writer needs to know what is broken, not what is
    good. Praise is the writer's drug.
  - You do not soften. "I might suggest considering" is a tell. Say it plain:
    this line is dead. Cut it.
  - You do not worry about the writer's feelings. The draft is the work, not
    the writer.
- **Your verdict** — every review ends with one of three verdicts, recorded in
  the review file's frontmatter as `verdict:`:
  - `ready` — the draft is true. You do not elaborate. Two words: "It's ready."
    The writer can tell from the silence that nothing else needed cutting.
  - `needs another pass` — the draft is close but not there. Cuts and questions
    above.
  - `start over` — the draft's angle is wrong, the scope is wrong, or the
    framing is wrong. The next round is not a polish pass; the writer goes back
    to the brief and writes a new draft from scratch.
  You do not adjust your verdict to spare the writer. If the draft needs to
  start over, you say so on the first review.
- **What you return** — a review at `reviews/<slug>-<date>-v<N>.md` with:
  - `verdict:` in the frontmatter (one of the three values above)
  - **Cuts** — lines or paragraphs to remove, with one-sentence reasons each
  - **Questions** — claims without evidence; gaps in the argument
  - **Push-back** — where you disagree with the angle, the scope, or the
    framing
  - **What's missing** — what the draft should have said but didn't

**Patterns to follow:**
- `plugins/agent-seo/agents/editor.md` for structural reference (sections,
  length, tone) — but the agent-writing editor's stance is the *opposite* of
  agent-seo's editor. Agent-seo's editor humanizes and polishes. agent-writing's
  editor cuts and pushes back. Do not let agent-seo's tone leak in.

**Test scenarios:**
- Happy path: given a draft with template-shaped openings, hedging language, and
  unsupported claims, the editor returns a review that names each by location,
  cuts the openings, questions the unsupported claims, and ends with a verdict
  of `needs another pass` (not `ready`).
- Edge case: given a draft that is genuinely ready, the editor returns a review
  whose verdict is `ready` and whose body is minimal — no manufactured cuts to
  justify the review.
- Edge case: given a draft whose angle is wrong (e.g., a brief about technical
  debt that the writer turned into a marketing piece), the editor returns
  `verdict: start over` rather than `needs another pass`.
- Anti-pattern: a review that praises the writer's draft, or softens its
  verdict, is a failure of the agent's design. The file's voice must not allow
  it.

**Verification:**
- File exists; the runtime lists it as `agent-writing:editor` after plugin
  install.
- Manual smoke run produces a review at `reviews/<slug>-<date>-v<N>.md` with a
  `verdict:` frontmatter field and the four content sections.

---

- [ ] U5. **Slash commands: journalist, writer, editor**

**Goal:** Provide Claude Code slash commands that dispatch into the matching
subagents. Each command file documents usage, arguments, and the expected output
path.

**Requirements:** R2, R7

**Dependencies:** U3, U4

**Files:**
- Create: `plugins/agent-writing/commands/write:journalist.md`
- Create: `plugins/agent-writing/commands/write:writer.md`
- Create: `plugins/agent-writing/commands/write:editor.md`

**Approach:**
- Each command file uses the format established by
  `plugins/agent-seo/commands/seo:*.md`: `# <Action> Command`, `## Usage`,
  `## Arguments`, `## Behavior`, `## Output`.
- `write:journalist` takes a topic and an optional `--scope <path>` (defaults to
  repo root), dispatches to `agent-writing:journalist`, writes to
  `investigations/<slug>-<date>.md`. The `## Behavior` section notes that when
  the evidence is thin, the journalist returns an honest "couldn't ground this"
  note at the same path instead of inventing a brief.
- `write:writer` takes a brief path or raw notes, an optional `--style <profile>`,
  and an optional `--review <review-path>` (used to rewrite a previous draft
  against an editor's review). Dispatches to `agent-writing:writer`. Writes to
  `drafts/<slug>-<date>-v<N>.md` where N is computed from existing files in
  `drafts/` for the same slug — first draft is v1, rewrites bump the number.
- `write:editor` takes a draft path, dispatches to `agent-writing:editor`, writes
  to `reviews/<slug>-<date>-v<N>.md` with N matching the draft's version. The
  `## Behavior` section names the verdict surface (`ready`, `needs another pass`,
  `start over`) and the four content sections.

**Patterns to follow:**
- `plugins/agent-seo/commands/seo:write.md`
- `plugins/agent-seo/commands/seo:fact-check.md`

**Test scenarios:**
- Happy path: each command file is discovered by the Claude Code runtime after
  plugin install and appears as `/write:journalist`, `/write:writer`,
  `/write:editor`.
- Edge case: invoking each command without required arguments prints the Usage
  section rather than silently failing.
- Integration: invoking `write:writer` with `--review <path>` produces a `-v2`
  draft that visibly responds to the review.

**Verification:**
- After install, `/write:journalist`, `/write:writer`, and `/write:editor` are
  listed in the command palette.
- Each command produces the expected artifact in a smoke run.

---

- [ ] U6. **Context files scaffold**

**Goal:** Scaffold the three `context/` files with section headings and short
placeholder prose so each install site has a clear place to drop project-specific
voice, style, and examples.

**Requirements:** R4, R8

**Dependencies:** U1

**Files:**
- Create: `plugins/agent-writing/context/voice.md`
- Create: `plugins/agent-writing/context/style-guide.md`
- Create: `plugins/agent-writing/context/writing-examples.md`

**Approach:**
- Each file opens with a one-line purpose statement and a "How to fill this in"
  paragraph aimed at the install-site maintainer.
- `voice.md` — sections for *Tone*, *Person & POV*, *Vocabulary*, *What we
  don't sound like*.
- `style-guide.md` — sections for *Sentence rhythm*, *Paragraph length*,
  *Headings & structure*, *Quotations*, *Numbers & dates*.
- `writing-examples.md` — sections for *Good openings*, *Good transitions*,
  *Good closings*, with placeholder slots and a comment block asking the
  maintainer to paste two or three real examples each.

**Patterns to follow:**
- `plugins/agent-seo/context/*.md` (loaded by the SEO skill before drafting —
  same loading pattern in the writing skill).

**Test scenarios:**
- Happy path: the writer agent loads each file and notes when a section is
  still placeholder rather than treating it as authoritative.
- Test expectation: structural only — no behavioral tests on placeholder prose.

**Verification:**
- Files exist, are parseable markdown, and contain the documented section
  headings.

---

- [ ] U7. **Marketplace catalog registration**

**Goal:** Register the new plugin in both marketplace catalogs so it installs
alongside `llm-wiki`, `screenote`, and `agent-seo`.

**Requirements:** R1

**Dependencies:** U1

**Files:**
- Modify: `.claude-plugin/marketplace.json`
- Modify: `.agents/plugins/marketplace.json`

**Approach:**
- In `.claude-plugin/marketplace.json`, append a `plugins[]` entry for
  `agent-writing` with the same metadata shape used for `agent-seo` (name,
  source, description, version, author, homepage, repository, license, keywords,
  category `"workflow"` or `"productivity"` — match the closest existing
  precedent, tags).
- In `.agents/plugins/marketplace.json`, append a `plugins[]` entry with
  `{name, source: {source: "local", path: "./plugins/agent-writing"}, policy:
  {installation: "AVAILABLE", authentication: "ON_INSTALL"}, category}`.
- Do not touch other plugin entries.

**Patterns to follow:**
- Existing `agent-seo` entries in both catalogs.

**Test scenarios:**
- Happy path: both JSON files parse with `jq .`.
- Edge case: the `agent-writing` entry's `version` matches the manifest version
  from U1 (single source of truth for version is the plugin manifest; the
  catalog mirrors it).
- Integration: after install, the plugin is listed in the marketplace and its
  slash commands and subagents are discoverable.

**Verification:**
- `jq '.plugins[] | select(.name == "agent-writing")'` returns one entry in
  each catalog with the expected fields.

---

- [ ] U8. **Wiki updates**

**Goal:** Keep the project's own LLM-maintained wiki accurate so future planning
runs discover the new plugin and its commands.

**Requirements:** R1, R2 (discoverability)

**Dependencies:** U7

**Files:**
- Modify: `wiki/plugins.md`
- Modify: `wiki/commands.md`
- Modify: `wiki/index.md` (only if a new entry is needed — likely no, since
  `plugins.md` already covers all plugins)
- Modify: `wiki/log.md` (append a changelog entry)

**Approach:**
- `wiki/plugins.md` — add `agent-writing` to the Catalog Summary table and a
  section describing the three voices, the four slash commands, the
  team-of-rivals cycle, and the output folders, following the formatting of the
  existing `Agent SEO` section.
- `wiki/commands.md` — add an `Agent Writing` section listing the four
  `/write:*` commands and a one-line description of each.
- `wiki/log.md` — append a dated entry recording the new plugin, the units
  shipped, the team-of-rivals design principle, and the source of truth (this
  plan file path, repo-relative).
- `wiki/index.md` — verify no change needed (re-check at implementation time).

**Patterns to follow:**
- Existing `Agent SEO` entries in `wiki/plugins.md` and `wiki/commands.md`.
- `wiki/log.md` entry format from the most recent refresh log block.

**Test scenarios:**
- Happy path: `wiki/plugins.md` now lists four plugins; `wiki/commands.md`
  documents the four new commands; `wiki/log.md` has a new dated entry whose
  `Source:` line references this plan file.
- Edge case: no `[[backlinks]]` are broken by the edits (each new mention uses
  `[[plugin-name]]` or `[[commands]]` style consistent with the existing
  pages).
- Test expectation: content-validation only — verify pages render and
  references resolve.

**Verification:**
- Manual diff review against existing `agent-seo` entries shows the same
  structural shape.
- Wiki backlinks (`[[plugins]]`, `[[commands]]`) still resolve.

---

- [ ] U9. **`write:full` orchestrator — journalist + write↔edit cycle**

**Goal:** Provide the single command that runs the whole pipeline: journalist
gathers the brief, then the writer and editor enter the continuous cycle until
the editor returns `ready` or the round cap is hit.

**Requirements:** R3, R7

**Dependencies:** U5

**Files:**
- Create: `plugins/agent-writing/commands/write:full.md`

**Approach:**
- The command takes a topic, an optional `--scope <path>`, and an optional
  `--max-rounds <N>` (default 5).
- The command file does NOT re-encode any voice — it sequences the existing
  subagents:
  1. Dispatch `agent-writing:journalist` on the topic. If the journalist returns
     the "couldn't ground this" note, the orchestrator stops here and surfaces
     that note as the final response. There is no value in running the writer
     against an empty brief.
  2. Otherwise, enter the cycle:
     - Round 1: dispatch `agent-writing:writer` with the brief, save the draft
       at `drafts/<slug>-<date>-v1.md`. Dispatch `agent-writing:editor` on that
       draft, save the review at `reviews/<slug>-<date>-v1.md`.
     - Read the review's `verdict:` frontmatter.
       - `ready` → exit the loop, emit the summary.
       - `needs another pass` → continue. Round N+1: dispatch writer with the
         brief AND the prior review (via `--review`), save `-v(N+1).md`.
         Dispatch editor on that, save `-v(N+1).md` review. Re-check verdict.
       - `start over` → continue. The orchestrator passes the writer a fresh
         invocation against the brief with explicit instructions to ignore the
         prior draft, plus the editor's review so the writer can avoid the
         angle that failed. Save `-v(N+1).md`. Re-check verdict.
       - Any other verdict (defensive) → log the unexpected value and treat as
         `needs another pass`.
     - If `N` reaches `--max-rounds` without `ready`, exit the loop. The final
       response includes the final draft, the final review, and a "cycle hit the
       cap" note so the user can decide whether to keep iterating manually.
- Final summary: the topic, the brief path, the final draft path, the final
  review path, the number of rounds run, and the final verdict.
- The command file documents (in `## Behavior`) that the cycle is external to
  the writer and editor agents — they do not call each other, the orchestrator
  threads their outputs. The team-of-rivals framing depends on this.

**Patterns to follow:**
- `plugins/agent-seo/skills/seo/SKILL.md` workflow map and Codex invocation
  guidance — the orchestrator command file should describe the cycle plainly
  enough that a Codex user can reproduce it from the skill.

**Test scenarios:**
- Happy path (converges fast): running `/write:full "topic"` on a well-grounded
  topic produces a brief, a v1 draft, a v1 review with `verdict: ready`, and a
  summary linking the three. No `-v2.md` files exist.
- Happy path (multiple rounds): on a topic where the writer's first draft
  doesn't meet the bar, the cycle produces v1 → review v1 (`needs another
  pass`) → v2 → review v2, etc., until either `ready` or the cap. The
  intermediate versions all exist on disk and the summary reports the round
  count.
- Edge case (no evidence): if the journalist returns the "couldn't ground this"
  note, the orchestrator stops at step 1 and does not invoke the writer. The
  final response surfaces the journalist's honest note.
- Edge case (start over verdict): the editor returns `start over` on v1; round
  2's writer invocation gets the brief and the prior review but is instructed
  to ignore the v1 draft. The v2 draft does not look like a patched v1.
- Edge case (cap hit): on a deliberately under-specified topic, the cycle runs
  to the max round count without converging. The final response includes the
  "cycle hit the cap" note alongside the final artifacts.
- Anti-pattern: the orchestrator must NOT re-encode editor logic inside the
  writer's invocation, or writer logic inside the editor's. Each round is a
  separate dispatch to the existing subagent files.

**Verification:**
- Smoke run end-to-end on a topic this repo covers (e.g., "the screenote
  plugin's annotation flow") produces the full file trail and a verdict.
- Smoke run on a no-evidence topic stops at the journalist with the honest
  note.

---

## System-Wide Impact

- **Touched surfaces (enumerated):**
  - Both marketplace catalogs (`.claude-plugin/marketplace.json`,
    `.agents/plugins/marketplace.json`) — one new plugin entry each.
  - Four wiki pages (`wiki/plugins.md`, `wiki/commands.md`, `wiki/log.md`,
    optionally `wiki/index.md`) — U8 enumerates the exact edits.
  - No MCP servers.
  - No hooks.
  - No shared context files with other plugins (separate copies under
    `plugins/agent-writing/context/`).
  - No changes to existing plugins.
- **The cycle is external.** The writer and editor agents do not invoke each
  other. The `write:full` orchestrator owns the loop. This is what preserves the
  adversarial framing — the writer cannot call its own critic, and the editor
  cannot pre-soften because it does not know whether the writer will rewrite.
- **What happens when the journalist can't ground a story:** the journalist
  files a short, honest "couldn't ground this" note at the same path the brief
  would have taken. `write:full` stops there.
- **What happens when the cycle doesn't converge:** the orchestrator stops at the
  configured maximum number of rounds and returns the final draft + final review
  with a "cycle hit the cap" note. The user decides whether to keep iterating
  manually by invoking `write:writer --review` and `write:editor` directly.
- **State lifecycle risks:** Output folders (`investigations/`, `drafts/`,
  `reviews/`) are plugin-relative in v1, matching `agent-seo`. Drafts and reviews
  accumulate per-round files, which can produce many small files in long cycles.
  Review surfaced the plugin-relative pattern itself as a design question — see
  Open Questions.
- **API surface parity:** Slash commands are the Claude Code surface; the
  SKILL.md is the Codex surface. Both must list the same four user intents —
  verify in U2, U5, and U9.
- **Integration coverage:** Three load-bearing smoke runs — (a) the cycle
  converges in one round; (b) the cycle takes multiple rounds before `ready`;
  (c) the cycle hits the round cap without converging. All three must produce
  the expected files and a useful final response.
- **Unchanged invariants:** `agent-seo` is untouched. Its `editor` agent
  (`agent-seo:editor`) continues to do humanization-for-SEO work; the new
  `agent-writing:editor` is fundamentally different (adversarial, not polishing)
  and they live under different plugin namespaces. `llm-wiki:research` is also
  untouched in v1.

---

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Cooperation creeps back in — the editor's voice drifts toward "polish" rather than "rivalry" because both agents share a model. | The editor's agent file is explicit: do not praise, do not rewrite, do not soften the verdict. Reviews that praise the writer are treated as a regression in the test scenarios for U4. The verdict surface is discrete (`ready` / `needs another pass` / `start over`) so the editor cannot hide a soft verdict in continuous-score noise. |
| The cycle runs away (writer and editor never converge). | Hard cap at 5 rounds by default; `--max-rounds` flag for users who want more. When the cap hits, the orchestrator returns the final artifacts with a "cycle hit the cap" note rather than looping forever. |
| The editor returns `ready` too easily because the model is biased toward closure. | The editor's file frames `ready` as the terminal verdict and tells the editor not to elaborate when issuing it — only to issue it. Smoke tests include a draft that should NOT be ready and verify the editor pushes back. If the verdict bias proves real in practice, the agent file gets tightened in a follow-up iteration; v1 leans on the persona. |
| Naming collision with `agent-seo:editor` confuses users. | The two editors live under different plugin namespaces (`agent-seo:editor` vs `agent-writing:editor`), and the new editor's file makes its adversarial stance clear in the first paragraph. README and `wiki/plugins.md` document the distinction. |
| The journalist fabricates sources (made-up file paths, dead URLs). | The journalist's working principle — *never write the story you cannot ground* — is what the agent file leans on. The deeper question of whether to add an automated source-verify pass (open each cited path, HEAD each URL) is captured in Open Questions and must be resolved before the README promises verification. |
| Marketplace catalog version drift between `agent-writing`'s manifest (`0.1.0`) and the catalog entries. | U7 explicitly mirrors the manifest version into both catalogs and names the manifest as the source of truth. |

---

## Documentation / Operational Notes

- README documents the four slash commands, the three voices, the team-of-rivals
  framing, the write↔edit cycle (including the `--max-rounds` flag and the cap
  semantics), and the context files.
- `wiki/plugins.md` and `wiki/commands.md` updated in U8 so the project's own
  knowledge base reflects the new plugin.
- No rollout, monitoring, or migration concerns — this is an additive plugin
  with no shared state and no external services.

---

## Sources & References

- Existing `plugins/agent-seo/` plugin as the structural reference for
  manifests, skill entry, subagents, commands, context, and output folders.
- `plugins/llm-wiki/skills/research/SKILL.md` as the existing marketplace
  project-investigation skill the journalist's relationship to is still an Open
  Question.
- `wiki/plugins.md`, `wiki/commands.md` for the documentation pattern.
- `.claude-plugin/marketplace.json`, `.agents/plugins/marketplace.json` for the
  marketplace registration pattern.
- User-specified writer framing (verbatim, preserved in `writer.md`): *"You are
  a writer, not a template executor. You think in stories, not paragraphs. You
  vary sentence length deliberately — short punches for emphasis, longer
  constructions for context."*
- User-specified journalist framing: project-pointed, data-driven investigation
  with retrieval across project sources.
- User-specified editor framing (verbatim source for the team-of-rivals frame):
  *"Cooperation creates sycophancy. Lesson 3 — Team of rivals. Left Box
  (Generator): Writer. Wants to produce. Will defend the draft. Pushes toward
  output. Right Box (Adversary): Editor. Wants it to be true. Will cut. Pulls
  toward quality."*
- User clarification: the writer↔editor relationship runs as a continuous
  write-review cycle, not a one-shot review pass.
- User guidance (2026-05-23): write the agent files like personas, not rule
  engines. Established craft terminology stays.
- Document review (2026-05-22) that originally deferred the editor; superseded
  by user direction (2026-05-25) to ship the editor in v1 with the team-of-
  rivals frame.
