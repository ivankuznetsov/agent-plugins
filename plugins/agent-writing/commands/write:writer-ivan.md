---
description: Personal writer for Ivan Kuznetsov. Composes writer.md (English) or writer-ru.md (Russian) as the base voice with writer-ivan.md as the identity layer. Defaults to Russian. Use when drafting a piece that will publish under Ivan's name.
---

# Writer Command — Ivan

Same Generator role as `/write:writer` — thinks in stories, varies sentence length deliberately, reads the draft aloud, defends and cuts adversarially against the editor. The difference is composition: a base voice (language-specific) gives the agent universal voice principles, and an identity layer (writer-ivan.md) gives the agent Ivan's portfolio and calibration on top.

## Usage

```text
/write:writer-ivan <brief-or-notes> [--lang ru|en] [--review <review-path>]
```

## Arguments

- **`<brief-or-notes>`** *(required)* — path to a journalist brief or raw notes.
- **`--lang ru|en`** *(optional)* — language for the draft. Defaults to `ru` (most of Ivan's writing is Russian). When `ru`, the base voice is `agents/writer-ru.md`; when `en`, it's `agents/writer.md`.
- **`--review <review-path>`** *(optional)* — path to a prior editor's review. When passed, the writer rewrites against that review and bumps the version suffix.

## Behavior

Dispatch the `agent-writing:writer-ivan` subagent. Behavior matches `/write:writer` exactly, with one composition step at the top:

1. Load the base voice — `agents/writer.md` if `--lang en`, otherwise `agents/writer-ru.md`. This carries the universal voice principles (rhythm, positions, image-not-editorial closings, specifics over generics, the rivalry with the editor).
2. Load the identity layer — `agents/writer-ivan.md`. This adds who is writing, what their portfolio is, and the calibration they bring.
3. Load the project context files — `context/voice.md`, `context/style-guide.md`, `context/writing-examples.md`. If the install site has language-specific variants (`context/voice-ru.md` etc.), load them in preference.
4. Follow the standard draft / rewrite workflow exactly as in `/write:writer`.

## Frontmatter

Every draft carries this frontmatter:

```yaml
---
title: <draft title>
source_brief: ./writing/investigations/<slug>-<date>.md
date: <YYYY-MM-DD>
round: <N>
word_count: <number>
lang: ru | en
author: ivan
---
```

The `author: ivan` field signals to any later pass (and to the editor) that this draft was produced under Ivan's identity layer.

## Output

`./writing/drafts/<slug>-<date>-v<N>.md` — `N` is 1 for the first draft, increments by one for each rewrite.

## Forking this command for your own persona

If you fork the plugin and create your own identity layer at `agents/writer-<yourname>.md`, copy this command file to `commands/write:writer-<yourname>.md` and change two things:

1. The agent reference in the dispatch step (replace `writer-ivan` with `writer-<yourname>`).
2. The default `--lang` if your primary writing language is different.

The base voice composition stays the same. The personal layer is the part that's yours.
