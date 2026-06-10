---
name: agent-writing
description: A team of three writing voices working as rivals. Use when the user asks for Agent Writing, agent-writing, to investigate a topic across a project's data, to draft a story-first piece from a brief, to run a writer-editor cycle on a draft, or to run an end-to-end journalist → writer ↔ editor pipeline. The writer and editor are deliberately adversarial — cooperation creates sycophancy — and they run as a continuous cycle until the editor's verdict is `ready` or a configured maximum number of rounds is reached. Artifacts land in the user's project working directory under `./writing/`. In Codex, users invoke this skill by asking for Agent Writing; in Claude Code, the same workflows are also exposed as /write:* commands.
---

# Agent Writing

Agent Writing ships three writing voices — a journalist, a writer, and an editor — that work together as a **team of rivals**. Codex uses this skill as the native entry point. Claude Code users can keep using the `/write:*` command files.

The team-of-rivals shape is load-bearing. The writer is the Generator: wants to produce, will defend the draft, pushes toward output. The editor is the Adversary: wants the draft to be *true*, will cut, pulls toward quality. **Cooperation creates sycophancy** — a single agent that drafts and polishes its own work will not cut what doesn't earn its place. So the writer and editor are set up against each other on purpose, and they run as a continuous write-edit cycle, not a single polish pass.

The journalist sits outside the rivalry: they investigate the topic and file a grounded brief that the writer and editor will fight over. Every citation in that brief gets verified against reality before the brief is final.

## Invocation

In Codex, respond to natural requests such as:

```text
Use Agent Writing to investigate the screenote plugin's annotation flow.
Use Agent Writing to draft a piece from ./writing/investigations/screenote-annotation-flow-2026-05-26.md.
Use Agent Writing to run the writer-editor cycle on the screenote piece until it's ready.
```

Do not promise Codex-native `/write:*` slash commands. Those command names are the Claude Code interface. When a Codex user mentions `/write:journalist`, `/write:writer`, `/write:editor`, or `/write:full`, run the equivalent workflow from this skill.

## Shared Ground Rules

- Load available context files from the plugin's `context/` directory before drafting or editing: `voice.md`, `style-guide.md`, `writing-examples.md`, `anti-examples.md`. These hold per-project voice. Treat any section that's still placeholder prose as unfilled rather than authoritative.
- **Output goes to the user's project working directory, not inside the plugin.** Save journalist briefs to `./writing/investigations/<slug>-<date>.md`, writer drafts to `./writing/drafts/<slug>-<date>-v<N>.md`, and editor reviews to `./writing/reviews/<slug>-<date>-v<N>.md`. The `./writing/` tree is created on demand. Users who don't want artifacts versioned can add `/writing/` to their project's `.gitignore`.
- Use lowercase hyphenated slugs and ISO dates in generated filenames: `screenote-annotation-flow-2026-05-26`.
- Each round of the writer-editor cycle gets a `-vN` suffix: `./writing/drafts/<slug>-<date>-v1.md`, `./writing/drafts/<slug>-<date>-v2.md`, with `./writing/reviews/<slug>-<date>-v<N>.md` reviewing the matching draft.
- Every factual claim in a journalist's brief carries a source pointer (file path + line, commit SHA, or URL that resolved). The journalist **verifies** each pointer against reality before the brief is final — `Read` for file paths, `git cat-file -e` for SHAs, HEAD requests for URLs. Failed verifications get a verifiable replacement, get cut, or get flagged `[unverified]` in the brief.
- The journalist's working principle is *never write the story you cannot ground*. When the evidence is thin, file an honest "couldn't ground this" note at the same path instead of a fabricated brief.
- The cycle is external to both the writer and the editor. Neither agent invokes the other from inside their own reasoning. The orchestrator (`write:full`) owns the loop. This is what preserves the rivalry.
- When the harness allows model selection for sub-agents, the orchestrator runs the editor on a **different model than the writer**. A same-model editor shares the writer's generation tics and reads them as natural prose — it grades a copy of its own homework. The editor's mechanical lint pass (see `agents/editor.md`) backstops the same blind spot when model diversity isn't available.
- The editor's lint pass and rule set apply to the **whole draft on every round** — sections accepted in earlier rounds are re-audited, because voice rules evolve mid-project and apply retroactively.

## Workflow Map

| User intent | Claude command equivalent | Output |
| --- | --- | --- |
| Investigate a topic | `/write:journalist [topic]` | `./writing/investigations/<slug>-<date>.md` (brief with Verification section or honest "couldn't ground this" note) |
| Draft from a brief (default voice) | `/write:writer [brief]` | `./writing/drafts/<slug>-<date>-v1.md` |
| Draft from a brief (Russian voice) | `/write:writer-ru [brief]` | `./writing/drafts/<slug>-<date>-v1.md` (with `lang: ru`) |
| Draft from a brief (Ivan's identity) | `/write:writer-ivan [brief] [--lang ru\|en]` | `./writing/drafts/<slug>-<date>-v1.md` (with `lang:` and `author: ivan`) |
| Rewrite against an editor's review | `/write:writer [brief] --review [review-path]` (or `/write:writer-ru` / `/write:writer-ivan` for the variants) | `./writing/drafts/<slug>-<date>-v<N+1>.md` |
| Review a draft as an adversary (default) | `/write:editor [draft-path]` | `./writing/reviews/<slug>-<date>-v<N>.md` (verdict: `ready` / `needs another pass` / `start over`) |
| Review a draft as an adversary (Russian voice) | `/write:editor-ru [draft-path]` | `./writing/reviews/<slug>-<date>-v<N>.md` with `lang: ru` (same verdicts; voice drift counts as a cut) |
| Run the full pipeline | `/write:full [topic]` | Brief, versioned drafts, versioned reviews; loop ends on `ready` or `--max-rounds` (default 5) |

## Role Summaries

- **Journalist** — `agents/journalist.md`. Reads the project's data the way a working tech journalist would. Files a grounded brief or an honest "I couldn't ground this" note. Verifies every citation against reality before finalizing. The source of truth the writer and editor will fight over.
- **Writer** *(Generator)* — `agents/writer.md`. Opens with the user's verbatim framing. Thinks in stories. Varies sentence length deliberately. Reads the draft aloud before returning it. Defends the draft against the editor on the merits, takes the cuts they cannot defend.
- **Writer — Russian** *(Generator, RU voice)* — `agents/writer-ru.md`. Same Generator role as the default writer; same rivalry with the editor. Replaces only the voice: a working engineer's notebook in Russian. Bilingual at the word level (loanwords and native idioms share the same paragraph), monolingual at the syntactic level (no English-rhythm constructions imported into Russian). Use when the brief, sources, or audience is Russian-speaking.
- **Writer — Ivan** *(Generator, identity layer)* — `agents/writer-ivan.md`. Personal identity layer for Ivan Kuznetsov's writing. Composes with `writer.md` or `writer-ru.md` (selected via `--lang`); declares who is writing (portfolio, recurring themes, authority calibration) on top of the base voice. Universal voice principles live in the base files; this file adds only what is genuinely personal. Also serves as a template — other contributors can fork to `writer-<theirname>.md` for their own identity layer.
- **Editor** *(Adversary)* — `agents/editor.md`. Reads the draft as a skeptic. Cuts what doesn't earn its place. Questions claims. Pushes back on the angle. Does not praise. Does not rewrite for the writer. Returns one of three verdicts: `ready`, `needs another pass`, or `start over`.
- **Editor — Russian** *(Adversary, RU voice)* — `agents/editor-ru.md`. Same adversarial role as the default editor; same verdict semantics. Adds a second test: does the draft sound like a working engineer's notebook in Russian, or has it drifted into translated journalism? Voice drift counts as a cut. Use to review drafts produced by `/write:writer-ru`, or as a focused follow-up pass when a default-editor review came back `ready` but the Russian still sounds translated.

## Investigate Workflow

Use this when the user asks to investigate a topic, gather facts about a project area, or produce a research brief.

1. Define the question. Strip the topic to its real shape — what is the user actually asking about?
2. Read local first: `git log` for history, `ripgrep` for language, `Read` for the files. Check the project's `wiki/` if present.
3. If `qmd search` is available (the `llm-wiki` plugin), use it after local reads.
4. Use web search only for claims that go outside the project. Every URL cited must have resolved during research.
5. Cross-check. If two sources disagree, name both in the brief.
6. Find the angle. Out of everything you read, what is the story?
7. Draft a brief with these sections: Topic, TL;DR, Timeline, Key Facts (each cited), People & Entities, Open Questions, Suggested Angle, Sources.
8. **Verify every citation before finalizing.** `Read` each cited file path and confirm the line is in range. Run `git cat-file -e <sha>` for each commit SHA. HEAD each URL. Add a Verification section to the brief listing each citation's pass/fail. Replace, cut, or `[unverified]`-flag any source that fails. Set the frontmatter `verification:` field to `passed` or `partial`.
9. File the brief at `./writing/investigations/<slug>-<date>.md`.
10. If the evidence is thin, file an honest "couldn't ground this" note at the same path instead. Name what you searched, what came back, and what would need to be true to file a real brief. Verification doesn't apply to "couldn't ground this" notes.

## Draft Workflow

Use this when the user asks to write from a brief, or to start from raw notes.

1. Read the brief (or notes) and the context files (`context/voice.md`, `context/style-guide.md`, `context/writing-examples.md`).
2. Start with a person, scene, or moment — not a definition.
3. Vary sentence length deliberately. Never let three sentences in a row land the same way.
4. Refuse template openings, hedging language, corporate words for human things, and conclusions that just summarize.
5. When the draft feels done, run the Read-Aloud Test: read it through with the reader's ear, fix what stumbles, break what repeats, cut what sounds like a template.
6. Save at `./writing/drafts/<slug>-<date>-v1.md` with frontmatter: title, source_brief, date, round, word_count.

## Rewrite Workflow

Use this when the user gives you a brief AND a prior editor's review (or invokes `write:writer --review`).

1. Read the editor's review all the way through before touching the draft.
2. Go line by line through the review's Cuts and Questions.
3. Cuts you can't defend: cut them. Cuts you can defend: rewrite the line to stand on its own merits without explanation.
4. Questions: answer them in the prose, not in a reply.
5. Push-back on the angle: decide. Either commit harder to the original angle or pivot — don't compromise into a draft that does neither.
6. If the prior verdict was `start over`, write a new draft from scratch. Take what you learned but don't try to salvage the old structure.
7. Save at `./writing/drafts/<slug>-<date>-v<N+1>.md`.

## Review Workflow

Use this when the user asks to edit a draft, or to review a draft adversarially.

1. Read the draft sentence by sentence. For each line, ask: what is this doing here?
2. Then paragraph by paragraph: what does this add?
3. Then the whole draft: did the writer commit to the angle, or hedge?
4. Mark every line that doesn't earn its place. Quote it, name where it is, give a one-sentence reason.
5. Question every claim that lacks a source pointer.
6. Surface what's missing — the question the draft didn't answer, the fact in the brief it left on the floor.
7. Push back on the angle if the writer flinched.
8. End with a verdict: `ready`, `needs another pass`, or `start over`.
9. File the review at `./writing/reviews/<slug>-<date>-v<N>.md` with frontmatter `verdict:` and the four sections (Cuts, Questions, Push-back, What's missing). Skip a section if it's empty — don't fill it for the sake of filling it.
10. Do not praise. Do not rewrite for the writer. Do not soften the verdict. Cooperation creates sycophancy.

## Full Cycle Workflow

Use this when the user asks to take a topic from research through to a finished draft (`/write:full`).

1. Run the Investigate Workflow (including verification) on the topic. If the result is an "I couldn't ground this" note, stop here and surface that note as the final response. There is no value in running the writer against an empty brief.
2. Otherwise, enter the cycle:
   - **Round 1:** Run the Draft Workflow on the brief → `./writing/drafts/<slug>-<date>-v1.md`. Run the Review Workflow on that draft → `./writing/reviews/<slug>-<date>-v1.md`.
   - Read the review's `verdict:`.
     - `ready` → exit the loop. Emit the summary.
     - `needs another pass` → continue. Run the Rewrite Workflow with the brief and the prior review → `./writing/drafts/<slug>-<date>-v2.md`. Run the Review Workflow on v2 → `./writing/reviews/<slug>-<date>-v2.md`. Re-check verdict.
     - `start over` → continue, but the writer's next round is a fresh draft from the brief (not a patch). Pass the prior review so the writer can avoid the angle that failed.
   - Repeat until verdict is `ready` or the round count reaches the configured maximum (default 5).
3. If the cap is hit without `ready`, return the final draft, the final review, and an explicit "cycle hit the cap" note so the user can decide whether to keep iterating manually with `/write:writer --review` and `/write:editor`.
4. Final response: the topic, the brief path, the final draft path, the final review path, the number of rounds run, and the final verdict.

The orchestrator threads outputs between rounds — the writer's input on round N+1 is the brief plus the editor's round-N review. Neither agent calls the other from inside their own reasoning. The loop lives in the orchestrator.
