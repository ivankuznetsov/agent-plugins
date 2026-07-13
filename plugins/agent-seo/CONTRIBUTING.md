# Contributing to Agent SEO

Thank you for improving Agent SEO. This repo supports both Claude Code and Codex, so changes should keep both plugin surfaces working.

## Project Surfaces

- Claude manifest: `.claude-plugin/plugin.json`
- Legacy Claude marketplace: `.claude-plugin/marketplace.json`
- Codex manifest: `.codex-plugin/plugin.json`
- Codex skill: `skills/seo/SKILL.md`
- Claude command workflows: `commands/seo:*.md`
- Claude agents: `agents/*.md`
- Optional Ruby tools: `data_sources/ruby/`

## Reporting Issues

When reporting bugs, include:

- Product used: Claude Code, Codex, or both.
- Install path: `ivankuznetsov/agent-plugins` or legacy `ivankuznetsov/claude-seo`.
- Command or skill request used.
- Expected behavior and actual behavior.
- Relevant environment details, especially Ruby/Bundler availability for analysis tools.

## Submitting Changes

1. Fork and clone the repository:

   ```bash
   git clone https://github.com/ivankuznetsov/agent-seo.git
   cd agent-seo
   ```

2. Create a feature branch:

   ```bash
   git checkout -b feature/your-feature-name
   ```

3. Make focused changes and update docs when behavior changes.
4. Run relevant checks.
5. Open a pull request with a summary, verification steps, and any install-path impact.

## Change Guidelines

- Keep plugin name `agent-seo` stable.
- Keep `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` versions synchronized.
- Preserve the legacy `.claude-plugin/marketplace.json` name and `source: "./"` path.
- Do not promise Codex-native `/seo:*` slash commands; Codex uses the installed skill.
- When updating Claude command behavior, update `skills/seo/SKILL.md` if Codex users need the same workflow.
- Ruby tooling must remain optional. Prompt-driven research, writing, humanization, fact-checking, optimization, rewriting, and analysis should still work without Ruby.

## Command Files

For `commands/seo:*.md` changes:

- Use clear usage examples.
- Include a process breakdown and expected output.
- Specify file management behavior for generated artifacts.
- Keep command names under the `/seo:*` namespace.

## Skill File

For `skills/seo/SKILL.md` changes:

- Write for Codex users who invoke the skill through natural language.
- Map natural-language requests to the same workflows as Claude commands.
- Include setup guidance when optional data sources or Ruby tools are missing.
- Keep frontmatter description broad enough for discovery without listing unsupported Codex slash commands as native commands.

## Agent Files

For `agents/*.md` changes:

- Define the agent mission and expertise clearly.
- Specify expected inputs and output format.
- Keep recommendations practical and tied to SEO outcomes.

## Context Files

For `context/` changes:

- Use clear section headers.
- Provide concrete examples.
- Keep templates brand-neutral unless an example directory explicitly names a brand.

## Verification

Use the checks that match your change:

```bash
jq . .claude-plugin/plugin.json
jq . .claude-plugin/marketplace.json
jq . .codex-plugin/plugin.json
cd data_sources/ruby
bundle exec ruby -Ilib:test test/*_test.rb
```

For marketplace releases, also update the shared `ivankuznetsov/agent-plugins` repo so both `.claude-plugin/marketplace.json` and `.agents/plugins/marketplace.json` point at the current `agent-seo` submodule SHA.

## License

By contributing, you agree that your contributions are licensed under the MIT license.
