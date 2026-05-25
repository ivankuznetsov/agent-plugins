# Journalist Command

Investigate a topic across the project's data and return a grounded brief. The journalist reads local code, git history, docs, the wiki, and the open web; cites every fact with a real source pointer; verifies every citation against reality before finalizing; and files the brief at `./writing/investigations/<slug>-<date>.md` in the user's project working directory. If the evidence is thin, the journalist files an honest "couldn't ground this" note at the same path instead of fabricating a brief.

## Usage

```text
/write:journalist <topic> [--scope <path>]
```

## Arguments

- **`<topic>`** *(required)* — the question to investigate. A short noun phrase or a one-sentence question. Examples: `the screenote plugin's annotation flow`, `how does llm-wiki's QMD search actually work`, `what changed in agent-seo between v0.9 and v1.1`.
- **`--scope <path>`** *(optional)* — restrict the journalist's local search to this directory. Defaults to the repository root. Useful when investigating a single plugin or subsystem.

## Behavior

Dispatch the `agent-writing:journalist` subagent. The journalist:

1. Defines the question, then maps the territory.
2. Reads local first: `git log`, `ripgrep`, `Read`, the `wiki/` directory.
3. Uses `qmd search` if available (the `llm-wiki` plugin).
4. Uses web search only for claims that go outside the project. Every URL cited must have resolved during research.
5. Cross-checks. Names disagreements explicitly.
6. Finds the angle and drafts the brief.
7. **Verifies every citation against reality before finalizing.** For each cited file path, the journalist `Read`s the file and confirms the line is in range. For each commit SHA, the journalist runs `git cat-file -e <sha>`. For each URL, the journalist HEADs it. The brief includes a Verification section listing each citation's pass/fail status; failed citations get either a verifiable replacement, removal of the dependent claim, or an inline `[unverified]` flag if the claim matters and the writer/editor need to see it as soft. Frontmatter's `verification:` field reports `passed` (everything verified) or `partial` (some citations did not verify; the dependent claims were resolved per the rules above).

The brief at `./writing/investigations/<slug>-<date>.md` has the following sections (skipping any that don't apply): Topic, TL;DR, Timeline, Key Facts (each cited inline), People & Entities, Open Questions, Suggested Angle, Sources, Verification.

**Working principle:** *never write the story you cannot ground.* When the journalist cannot collect enough grounded evidence to file a real brief, they file an honest "I couldn't ground this" note at the same path — naming what was searched, what came back, and what would need to be true to file a brief. This is not a failure; it is the correct behavior. Padding a brief with unsourced claims is the failure. Verification doesn't apply to a "couldn't ground this" note.

## Output

`./writing/investigations/<slug>-<date>.md` — relative to the user's project working directory (not inside the plugin). The `./writing/` tree is created on demand if it doesn't exist.

Filename uses a lowercase hyphenated slug derived from the topic and an ISO date. Example: `./writing/investigations/screenote-annotation-flow-2026-05-26.md`.

When the evidence is thin, the same file at the same path holds the "I couldn't ground this" note instead of a full brief. Inspect the file to see which shape it took.
