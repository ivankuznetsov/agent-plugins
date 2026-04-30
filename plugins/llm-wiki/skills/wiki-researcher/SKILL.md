---
name: wiki-researcher
description: Search QMD-indexed project and main cross-project LLM wikis for past patterns, decisions, solutions, and pitfalls before planning or implementation. Use before feature planning, bug fixing, refactoring, architecture work, or code changes when a project wiki may exist.
---

# Wiki Researcher

Search the project wiki and main cross-project wiki before planning or implementation. Produce a concise Past Knowledge section that downstream planning or coding can use.

## Step 1: Identify Context

Determine:

- Current project name: `basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"`
- Whether `wiki/` exists in the repo.
- Whether `~/wikis/master/wiki/` exists.
- Whether `~/wikis/main/wiki/` exists.
- Whether QMD MCP tools, `qmd` CLI, or only `rg` are available.

## Step 2: Search With the Best Available Tool

### Preferred: QMD MCP

Use at most two QMD MCP query calls. Do not fire many QMD calls in parallel; combine related searches into the `searches` array.

Project search:

```json
{
  "searches": [
    { "type": "lex", "query": "<3-5 key terms>" },
    { "type": "vec", "query": "<natural-language task question>" }
  ],
  "collections": ["<current-project-name>"],
  "limit": 10
}
```

Main cross-project search:

```json
{
  "searches": [
    { "type": "lex", "query": "<key terms>" },
    { "type": "vec", "query": "patterns for <feature domain>" }
  ],
  "collections": ["master"],
  "limit": 10
}
```

Use the `master` QMD collection for the main cross-project wiki when available. If the environment uses a `main` collection instead, query `main`.

Read the top 3-5 relevant pages with QMD get or multi-get.

### Fallback: QMD CLI

```bash
qmd query "<topic>" --collection "<current-project-name>"
qmd query "<topic>" --collection master
# or, if the cross-project wiki is indexed as main:
qmd query "<topic>" --collection main
```

### Fallback: ripgrep

```bash
rg "<key terms>" wiki/ --type md -C 2
rg "<key terms>" ~/wikis/master/wiki/ --type md -C 2
rg "<key terms>" ~/wikis/main/wiki/ --type md -C 2
```

Skip missing directories gracefully.

## Step 3: Read Important Pages

Prioritize:

- `wiki/decisions.md`
- `wiki/technical-debt.md`
- `wiki/gaps.md`
- `wiki/architecture.md`
- `~/wikis/master/wiki/patterns.md`
- `~/wikis/master/wiki/learnings.md`
- `~/wikis/main/wiki/patterns.md`
- `~/wikis/main/wiki/learnings.md`

Only cite or summarize pages actually read.

## Step 4: Produce Past Knowledge

Return this structure:

```markdown
### Past Knowledge

**Relevant wiki pages:**
- ...

**Applicable patterns:**
- ...

**Past decisions that constrain this work:**
- ...

**Known pitfalls:**
- ...

**Reusable components:**
- ...

**Gaps this work could fill:**
- ...
```

If no wiki exists, say that explicitly and suggest running `bootstrap-wiki`.

## Rules

- Search wiki context before codebase exploration when wiki context exists.
- Do not claim wiki facts unless a page was read.
- Prefer concise synthesis over dumping search results.
- Preserve uncertainty and missing coverage as gaps.
