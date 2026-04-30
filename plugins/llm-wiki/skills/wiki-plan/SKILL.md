---
name: wiki-plan
description: Plan a feature, bugfix, refactor, or improvement with wiki research first. Searches project and main cross-project wiki context, synthesizes Past Knowledge, then delegates to Compound Engineering planning when available or writes a standalone plan outline.
---

# Wiki Plan

Plan with wiki knowledge first. Use this when the user asks to plan work and wants existing project knowledge, prior decisions, or cross-project patterns included.

Argument: feature description, bug report, refactor, or improvement idea.

## Feature Description

<feature_description>
$ARGUMENTS
</feature_description>

If the feature description is empty, ask the user what they want to plan and wait for the answer.

## Step 1: Run Wiki Research

Use the `research` skill on the feature description before any other planning research.

The output must include a `Past Knowledge` section with:

- Relevant wiki pages
- Applicable patterns
- Past decisions that constrain the work
- Known pitfalls
- Reusable components
- Gaps this work could fill

If no wiki exists, continue with an explicit note:

```markdown
### Past Knowledge

No project wiki was found. Consider running `bootstrap` after this plan. Proceeding with normal planning.
```

## Step 2: Delegate to Compound Engineering When Available

If Compound Engineering planning is installed, invoke it with the original feature description plus the Past Knowledge section.

Common Codex installed form:

```text
$compound-engineering:ce-plan
```

Common Claude/Codex skill name:

```text
compound-engineering:ce-plan
```

Use the platform's available skill invocation mechanism. Do not pretend delegation happened if the skill is unavailable.

## Step 3: Standalone Fallback

If Compound Engineering planning is unavailable, create a concise standalone implementation plan with:

- Problem frame
- Past Knowledge
- Proposed approach
- Files or areas to inspect
- Implementation steps
- Test scenarios
- Risks and open questions

Keep the plan grounded in source files and wiki pages actually read.

## Rules

- Wiki research always happens before planning.
- Use at most two QMD MCP query calls; combine sub-searches.
- QMD is optional; fall back to `qmd` CLI or `rg`.
- Do not overload a generic `plan` command. This skill is `wiki-plan`.
- Carry the Past Knowledge section into the final plan.
