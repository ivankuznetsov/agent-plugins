---
description: Russian-language writer. Same role as /write:writer (Generator in the team of rivals), but produces in the working-engineer's-notebook voice instead of the default voice. Use when the brief or notes are Russian, or the target audience is Russian-speaking.
---

# Writer Command — Russian

Draft from a journalist's brief, or rewrite a prior draft against an editor's review. Same Generator role as `/write:writer` — thinks in stories, varies sentence length deliberately, reads the draft aloud before returning it, defends and cuts adversarially against the editor. The only difference: the voice. Saves to `./writing/drafts/<slug>-<date>-v<N>.md`.

Use this command when:
- The journalist's brief is in Russian, or quotes Russian sources heavily.
- The user explicitly asks for Russian output.
- The piece is for a Russian-speaking audience.

For an English-language piece, use `/write:writer`.

## Usage

```text
/write:writer-ru <brief-or-notes> [--review <review-path>]
```

## Arguments

- **`<brief-or-notes>`** *(required)* — path to a journalist brief or raw notes the writer should draft from.
- **`--review <review-path>`** *(optional)* — path to a prior editor's review. When passed, the writer rewrites against that review and bumps the version suffix. Without this argument, the writer produces a first draft (`-v1`).

## Behavior

Dispatch the `agent-writing:writer-ru` subagent. The agent is the same Generator as the default writer in every dimension *except voice*. Behavior splits on whether `--review` is present.

### First draft (no `--review`)

1. Load context: `agents/writer-ru.md` for the voice persona, plus `context/voice.md`, `context/style-guide.md`, `context/writing-examples.md` if present. If the install site has a Russian-specific voice file at `context/voice-ru.md`, load it in preference to `context/voice.md`.
2. Read the brief.
3. Open with a person, scene, or moment — not a definition. The "Russian engineer's notebook" persona shapes *how* you open, not *whether* you open with a scene.
4. Vary sentence length deliberately. Never let three sentences in a row land the same way.
5. Refuse template openings ("В сегодняшнем мире…", "Когда речь заходит о…", "Важно отметить, что…"), hedging language, corporate words for human things, and conclusions that just summarize.
6. Hold the Russian-voice persona while drafting: state what is rather than chanting what isn't; let technical loanwords and native idioms share the same paragraph; do not import English rhythms.
7. Run the Read-Aloud Test before returning, with the persona's specific question: *does this sound like a sentence a working engineer would enter in their own notebook for themselves and a peer?* If a sentence sounds like Medium, podcast, YouTube, longread, or TechCrunch — rewrite.
8. Save the draft at `./writing/drafts/<slug>-<date>-v1.md`.

### Rewrite (with `--review`)

1. Compute `N+1` from the existing draft version (read the review's filename or frontmatter to determine the round number).
2. Load context files (including `agents/writer-ru.md` for the voice persona).
3. Read the editor's review all the way through before touching the draft.
4. Go line by line through Cuts and Questions. Cuts you can't defend: cut them. Cuts you can defend: rewrite the line so it stands on its own merits, in the persona's voice. Questions: answer them in the prose, not in a reply.
5. Push-back on the angle: decide. Either commit harder to the original angle, or pivot — don't compromise into a draft that does neither.
6. If the prior verdict was `start over`, write a new draft from scratch in the persona's voice. Take what you learned but don't try to salvage the old structure.
7. Run the Read-Aloud Test with the persona's question.
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
lang: ru
---
```

The `lang: ru` field signals to the editor (and to any later pass) that this draft was produced under the Russian-voice persona. The round number matches the version suffix.

## Output

`./writing/drafts/<slug>-<date>-v<N>.md` — `N` is 1 for the first draft, increments by one for each rewrite. Slug and date are derived from the source brief's filename.

## Note on the editor

The editor (`/write:editor`) is **not** language-aware in this plugin. It will review a Russian draft using its default Generator-vs-Adversary discipline, which catches structural problems (angle, coverage, claims without evidence). It may *not* automatically catch voice drift — calques from English, narrator-establishing-shot openers, paired-negation flourishes, stacked triple negations, theatrical character descriptions. If those slip through, you can either:

- Run a focused follow-up pass by invoking `/write:editor` with explicit instructions to scrutinize for those patterns. The voice persona in `agents/writer-ru.md` is the canonical reference for what to flag.
- Or simply do another `/write:writer-ru` round with the editor's structural review and the voice persona reasserted — the writer-ru agent has the voice internalized and can self-correct.

This is by design. The persona-vs-rules principle lives on the *producing* agent. The editor stays a structural adversary.
