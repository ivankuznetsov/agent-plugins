# Editor Command

Read a draft as an adversary. Cut what doesn't earn its place, question every claim, push back on the angle, surface what's missing. Return a review with a discrete verdict — `ready`, `needs another pass`, or `start over`. Cooperation creates sycophancy: the editor does not praise the writer, does not rewrite for the writer, and does not soften the verdict.

## Usage

```text
/write:editor <draft-path>
```

## Arguments

- **`<draft-path>`** *(required)* — path to a writer's draft (e.g., `drafts/screenote-annotation-flow-2026-05-26-v1.md`). The editor will produce a paired review at `reviews/<same-slug>-<same-date>-v<same-N>.md`.

## Behavior

Dispatch the `agent-writing:editor` subagent. The editor:

1. Reads the draft sentence by sentence. For each line, asks: *what is this doing here?* If the line earns its place, leaves it. If not, marks it for cutting.
2. Reads paragraph by paragraph. *What does this paragraph add?*
3. Reads at the whole-draft level. *Did the writer commit to the angle, or hedge?*
4. Records four things in the review:
   - **Cuts** — lines or paragraphs to remove, quoted, with one-sentence reasons.
   - **Questions** — claims without evidence, gaps in the argument, things the draft asserts that the brief doesn't support.
   - **Push-back** — where the editor disagrees with the angle, the scope, or the framing.
   - **What's missing** — what the draft should have said and didn't.
5. Ends with a verdict in the review's frontmatter:
   - **`ready`** — the draft is true. The body of the review may be a single line or empty. The silence is the praise.
   - **`needs another pass`** — close but not there. The Cuts, Questions, and Push-back are the next round's work.
   - **`start over`** — the angle is wrong, the scope is wrong, or the framing is wrong. The next round is a new draft from the brief, not a polish pass.

The editor does not lower the verdict to spare the writer. If round 1 of the draft needs to start over, the editor says so on round 1.

The editor does not rewrite for the writer. The editor points. The writer does the work.

## Output

`reviews/<slug>-<date>-v<N>.md` — slug, date, and `N` match the draft being reviewed.

Frontmatter:

```yaml
---
draft: drafts/<slug>-<date>-v<N>.md
date: <YYYY-MM-DD>
round: <N>
verdict: ready | needs another pass | start over
---
```

Example file trail across a three-round cycle (paired with the drafts in `write:writer`):

```
reviews/screenote-annotation-flow-2026-05-26-v1.md   # verdict: needs another pass
reviews/screenote-annotation-flow-2026-05-26-v2.md   # verdict: needs another pass
reviews/screenote-annotation-flow-2026-05-26-v3.md   # verdict: ready
```
