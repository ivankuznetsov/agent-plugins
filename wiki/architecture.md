# Architecture

`agent-plugins` distributes five independently versioned plugin directories.
The two root catalogs—`.claude-plugin/marketplace.json` and
`.agents/plugins/marketplace.json`—plus the top-level directories under
`plugins/` define the shipped inventory. `plugin-surfaces.json` must reconcile
that union; it cannot hide a catalog-only or directory-only plugin.

Each workflow's behavior lives under `plugins/<name>/skills/`. The standard
library generator reads the contract and canonical skills, then checks in:

- Claude compatibility command wrappers and normalized manifests;
- Codex metadata pointing at the canonical skill roots;
- Pi and OpenClaw skill adapters whose references remain inside the package;
- Pi/OpenClaw package metadata, the root catalogs, and semantic hash lock.

Generation is deletion-aware: marker-owned adapters and wrappers that are no
longer declared are pruned, while unrelated hand-written files are preserved.
Native smoke gates compare exact installed inventories rather than accepting a
subset, so stale generated skills cannot survive package validation.

Adapters may vary only in declared frontmatter, invocation syntax, tool
vocabulary, lifecycle notes, and install paths. Safety, error handling,
resources, and workflow behavior remain canonical. Package validation copies
each plugin alone and rejects symlinks, absolute paths, parent escapes, missing
resources, and references to another plugin.

OpenClaw needs a JavaScript entry to activate manifest-declared skills. The
generated entry is intentionally content-only and registers no runtime
capabilities. Native discovery runs from isolated home/config directories for
all four hosts.

Screenote's bearer-safe launcher reads its approved command tuples from the
generated contract artifact, while a shipped workflow runtime validates JSON
collections, pagination, and identifiers before canonical skills act on them.
LLM Wiki's shared transactional refresh runner dispatches exactly one configured
owner, including a validated OpenClaw workspace agent, from a disposable refresh
worktree.
