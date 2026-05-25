# Writer Command

Draft from a journalist's brief, or rewrite a prior draft against an editor's review. The writer is the Generator: thinks in stories, varies sentence length deliberately, reads the draft aloud before returning it. Saves to `./writing/drafts/<slug>-<date>-v<N>.md`.

## Usage

```text
/write:writer <brief-or-notes> [--style <profile>] [--review <review-path>]
```

## Arguments

- **`<brief-or-notes>`** *(required)* — path to a journalist brief (e.g., `./writing/investigations/screenote-annotation-flow-2026-05-26.md`) or raw notes the writer should draft from.
- **`--style <profile>`** *(optional)* — name of a voice profile in `context/`. If the install site keeps multiple voice variants (e.g., `context/voice-marketing.md`, `context/voice-internal.md`), this selects one. Defaults to `context/voice.md`.
- **`--review <review-path>`** *(optional)* — path to a prior editor's review (e.g., `./writing/reviews/screenote-annotation-flow-2026-05-26-v1.md`). When passed, the writer rewrites against that review and bumps the version suffix. Without this argument, the writer produces a first draft (`-v1`).

## Behavior

Dispatch the `agent-writing:writer` subagent. Behavior splits on whether `--review` is present.

### First draft (no `--review`)

1. Load context: `context/voice.md` (or the selected `--style` profile), `context/style-guide.md`, `context/writing-examples.md`.
2. Read the brief.
3. Open with a person, scene, or moment — not a definition.
4. Vary sentence length deliberately. Never let three sentences in a row land the same way.
5. Refuse template openings ("In today's…", "When it comes to…", "It is important to note…"), hedging language, corporate words for human things, and conclusions that just summarize.
6. Run the Read-Aloud Test before returning: read the draft through with the reader's ear, fix what stumbles, break what repeats, cut what sounds like a template.
7. Save the draft at `./writing/drafts/<slug>-<date>-v1.md`.

### Rewrite (with `--review`)

1. Compute `N+1` from the existing draft version (read the review's filename or frontmatter to determine the round number).
2. Load context files.
3. Read the editor's review all the way through before touching the draft.
4. Go line by line through Cuts and Questions. Cuts you can't defend: cut them. Cuts you can defend: rewrite the line so it stands on its own merits. Questions: answer them in the prose, not in a reply.
5. Push-back on the angle: decide. Either commit harder to the original angle, or pivot — don't compromise into a draft that does neither.
6. If the prior verdict was `start over`, write a new draft from scratch. Take what you learned but don't try to salvage the old structure.
7. Run the Read-Aloud Test on the new draft.
8. Save the draft at `./writing/drafts/<slug>-<date>-v<N+1>.md`.

### Frontmatter

Every draft carries this frontmatter:

```yaml
---
title: <draft title>
source_brief: ./writing/investigations/<slug>-<date>.md
date: <YYYY-MM-DD>
round: <N>
word_count: <number>
---
```

The round number matches the version suffix.

## Output

`./writing/drafts/<slug>-<date>-v<N>.md` — `N` is 1 for the first draft, increments by one for each rewrite. The slug and date are derived from the source brief's filename so all rounds share the same prefix.

Example file trail across a three-round cycle:

```
./writing/drafts/screenote-annotation-flow-2026-05-26-v1.md
./writing/drafts/screenote-annotation-flow-2026-05-26-v2.md
./writing/drafts/screenote-annotation-flow-2026-05-26-v3.md
```
