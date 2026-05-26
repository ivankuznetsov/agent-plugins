# Agent Writing

Agent Writing is a Claude Code and Codex plugin that ships three writing voices working as a **team of rivals**: a journalist who investigates and grounds, a writer who drafts, and an editor who cuts. The writer and editor run as a continuous cycle until the editor says the draft is ready.

The plugin lives alongside `agent-seo`, `llm-wiki`, and `screenote` in the shared `ivankuznetsov/agent-plugins` marketplace.

## Why three voices

Cooperation creates sycophancy. A single agent that drafts and then polishes its own work will not cut what doesn't earn its place — it will praise the parts it just wrote, soften its own verdicts, hedge instead of cutting. The fix is to set the editor against the writer as a rival: same model, different job, no incentive to flatter.

- **Journalist** — investigates. Reads the code, the git history, the docs, the wiki, the open web. Returns a brief with cited sources and an angle. Every citation is verified against reality before the brief is final (file paths read, commit SHAs checked with `git cat-file`, URLs HEADed). Never writes the story they cannot ground.
- **Writer** *(the Generator)* — wants to produce. Defends the draft. Pushes toward output. Thinks in stories. Varies sentence length deliberately. Reads the draft aloud before returning it.
- **Editor** *(the Adversary)* — wants the draft to be *true*, not finished. Cuts what doesn't earn its place. Questions claims. Pushes back on the angle. Does not praise. Does not rewrite for the writer.

The journalist sits outside the writer/editor rivalry: their job is to do the grounding so the writer has real material to work from and the editor has facts to hold the writer accountable to. The journalist is the source of truth the rivalry fights over.

## Installation

### Claude Code

```text
/plugin marketplace add ivankuznetsov/agent-plugins
/plugin install agent-writing@aikuznetsov-marketplace
```

### Codex

```bash
codex plugin marketplace add ivankuznetsov/agent-plugins
```

Then open Codex, run `/plugins`, select `aikuznetsov-marketplace`, and install `agent-writing`.

Codex loads Agent Writing as a skill, not as native `/write:*` slash commands. Ask for the skill by name:

```text
Use Agent Writing to investigate the screenote plugin's annotation flow.
Use Agent Writing to draft a piece from ./writing/investigations/screenote-annotations-2026-05-26.md.
Use Agent Writing to run the writer-editor cycle on ./writing/drafts/screenote-annotations-2026-05-26-v1.md.
```

## Slash commands (Claude Code)

| Command | Description |
| --- | --- |
| `/write:journalist <topic>` | Investigate a topic across the project's data; return a grounded brief or an honest "couldn't ground this" note. |
| `/write:writer <brief-or-notes>` | Draft from a brief. With `--review <path>`, rewrite a previous draft against an editor's review. |
| `/write:writer-ru <brief-or-notes>` | Same as `/write:writer`, but produces in the working-engineer's-notebook voice in Russian. Use when the brief or audience is Russian. |
| `/write:editor <draft-path>` | Read the draft as an adversary. Return cuts, questions, push-back, and a verdict: `ready`, `needs another pass`, or `start over`. |
| `/write:full <topic>` | Run the full pipeline: journalist gathers the brief, then the writer and editor cycle until `ready` or `--max-rounds` (default 5). |

## The write-edit cycle

`/write:full` is the orchestrator. It does not re-encode any voice — it sequences the three subagents:

1. The journalist investigates the topic and files a brief at `./writing/investigations/<slug>-<date>.md`. Every citation is verified against reality before the brief is final. If the evidence is thin, the journalist files a short "couldn't ground this" note instead, and the cycle stops there.
2. The writer drafts from the brief and saves it at `./writing/drafts/<slug>-<date>-v1.md`.
3. The editor reads the draft as an adversary and files a review at `./writing/reviews/<slug>-<date>-v1.md` with one of three verdicts: `ready`, `needs another pass`, or `start over`.
4. If `ready`, the cycle ends and the summary links the brief, the final draft, and the final review. Otherwise, the writer reads the editor's review, takes the cuts they cannot defend, defends the choices they stand behind, and rewrites — saving `./writing/drafts/<slug>-<date>-v2.md`. The editor reviews v2. The loop continues.
5. The cycle stops at the editor's `ready` verdict or after the configured maximum number of rounds (default 5). When the cap is hit without `ready`, the orchestrator returns the final artifacts with a "cycle hit the cap" note so the user can decide whether to keep iterating manually.

The cycle is external to both the writer and the editor. Neither agent invokes the other. This is what preserves the rivalry: the writer can't call its own critic, and the editor can't pre-soften because it does not know whether the writer will rewrite.

## Output folders

All artifacts land in the **user's project working directory**, not inside the plugin:

```
<your-project>/
└── writing/
    ├── investigations/   # journalist briefs (with Verification sections)
    ├── drafts/           # writer drafts (versioned: -v1.md, -v2.md, …)
    └── reviews/          # editor reviews (versioned: -v1.md, -v2.md, …)
```

The `./writing/` tree is created on demand. Each round of the cycle leaves a versioned draft and a versioned review on disk so the back-and-forth between writer and editor stays inspectable after the fact. If you don't want generated artifacts in your project's git history, add `/writing/` to your project's `.gitignore`.

## Per-project voice and style

Three context files under `context/` let each install site fill in project-specific voice, style, and examples:

- `context/voice.md` — tone, person/POV, vocabulary, what you don't sound like.
- `context/style-guide.md` — sentence rhythm, paragraph length, headings, quotations, numbers.
- `context/writing-examples.md` — two or three real examples each of good openings, transitions, and closings.

The agents load these files before drafting. They ship empty in this repo — fill them in at install time for your project.

## Note on the editor name

This plugin's editor (`agent-writing:editor`) is **adversarial** — it cuts and pushes back, it does not polish. It is fundamentally different from `agent-seo`'s editor (`agent-seo:editor`), which humanizes SEO content. The two live under different plugin namespaces, so they do not collide; just don't expect them to behave the same.
