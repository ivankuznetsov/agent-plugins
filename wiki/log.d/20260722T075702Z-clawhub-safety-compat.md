# 2026-07-22 — ClawHub safety and compatibility batch

Coalesced five queued source records into their three final outcomes. Agent SEO
2.0 makes the legacy scrubber and Ruby CLI read-only, removes the cleaned-output
contract and repo-local dotenv loading, preserves provenance, defaults editorial
work to new artifacts, gates existing-path edits and live data access on explicit
scope, and excludes development-only material from the ClawHub bundle.

LLM Wiki 0.3 separates requested wiki creation from persistent automation,
requires both consent flags before automatic dispatch, inlines the canonical
Pi/OpenClaw workflows, and uses collision-safe `wiki-*` names. The final
`dc69df8` source supersedes the provider-sandbox variants at `ce506cf` and
`0bbc7f0`: provider execution remains in the established bounded direct
transaction and adds no `bubblewrap` or `sandbox-exec` runtime dependency.

The OpenClaw compatibility patch declares
`openclaw.compat.pluginApi >=2026.7.1-beta.2` from the exact tested host pin and
bumps all five packages to their current patch versions. The commits do not
prove upstream release publication, ClawHub scan completion, public visibility,
or compatibility with older OpenClaw versions; those remain gaps. Page coverage
did not change, so `wiki/index.md` was left untouched, and the compiled
`wiki/log.md` was not edited.
