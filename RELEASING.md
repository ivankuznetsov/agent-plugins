# Releasing

The five plugins are independently versioned. Each release gets one tag and
GitHub release named `<plugin>-vX.Y.Z`; never combine their release numbers.

## Version markers

Change these together for the plugin being released:

- `plugin-surfaces.json#plugins[].version` (the packaging authority);
- `.claude-plugin/marketplace.json`;
- `plugins/<plugin>/.claude-plugin/plugin.json`;
- `plugins/<plugin>/.codex-plugin/plugin.json`;
- a plugin-local `.claude-plugin/marketplace.json`, when present;
- `plugins/<plugin>/CHANGELOG.md`.

`package.json`, `openclaw.plugin.json`, OpenClaw's content-only entry, host
adapters, Claude compatibility command wrappers, and
`plugin-surfaces.lock.json` are generated. Do not edit them directly.

The Codex root marketplace has no version field; it resolves the installed
version from the plugin package metadata.

## Release procedure

1. For an upstream-backed plugin, publish upstream first (see below) and vendor
   the exact released canonical tree.
2. Update the plugin version in the contract, root Claude marketplace, native
   Claude/Codex manifests, optional plugin-local marketplace, and changelog.
3. Regenerate all checked-in package surfaces:

   ```bash
   python3 scripts/generate-agent-packages.py
   ```

4. Run the required offline gates:

   ```bash
   python3 scripts/validate-agent-packages.py --inventory
   python3 scripts/generate-agent-packages.py --check
   python3 -m unittest discover -s tests -v
   ```

5. Install the exact four CI-pinned host versions from
   `plugin-surfaces.json`, then run native discovery:

   ```bash
   REQUIRE_AGENT_CLI=1 bash scripts/smoke-agent-packages.sh all
   ```

6. Open and merge a PR only after the required fast job and all four native
   matrix legs pass. For Screenote releases, also run the manually dispatched
   protected integration against its disposable project fixture.
7. From `main`, create the plugin-specific tag and release using that version's
   changelog section:

   ```bash
   awk '/^## \[X.Y.Z\]/{f=1; print; next} /^## \[/{f=0} f' \
     plugins/<plugin>/CHANGELOG.md > /tmp/plugin-release-notes.md
   gh release create <plugin>-vX.Y.Z --target main \
     --title "<plugin> X.Y.Z" --notes-file /tmp/plugin-release-notes.md
   ```

Users update Claude Code and Codex marketplaces normally. Pi and OpenClaw users
reinstall/update the copied package directory according to their host's native
package command, then restart the host so generated skills are rediscovered.

## Upstream-backed vendor order

### LLM Wiki

`plugins/llm-wiki/` is vendored from
[`ivankuznetsov/llm-wiki`](https://github.com/ivankuznetsov/llm-wiki). Release
`vX.Y.Z` upstream first, then copy the released canonical files without nested
Git metadata. Repository-owned Pi/OpenClaw adapters are regenerated after the
copy; generation drift must be clean before tagging
`llm-wiki-vX.Y.Z` here.

The worktree-safe `templates/post-commit-refresh.sh` and
`templates/compile-log.sh` remain byte-identical with their upstream/hive
counterparts.

### Agent SEO

`plugins/agent-seo/` is vendored from
[`ivankuznetsov/agent-seo`](https://github.com/ivankuznetsov/agent-seo).
Canonical skill and resource changes release there first. Vendor that tag,
then regenerate the repository-owned legacy/Pi/OpenClaw adapters and tag the
matching `agent-seo-vX.Y.Z` release here.

### Screenote CLI baseline

The Screenote plugin is released here, while its external CLI is released from
[`ivankuznetsov/screenote-cli`](https://github.com/ivankuznetsov/screenote-cli).
Keep the contract PR, merge SHA, public test ref, and eventual minimum release
as separate fields in `plugin-surfaces.json`. The current plugin baseline is
CLI v0.4.1 from PR 18. When that baseline advances, update all four provenance
fields and compatibility docs, rerun offline/live tests, and do not copy the
CLI implementation into skills.
