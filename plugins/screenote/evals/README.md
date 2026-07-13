# Evaluations

## Structural Linting

Deterministic checks on both Claude Code and Codex SKILL.md mirrors — no API calls, runs instantly.

    ./evals/lint-skills.sh
    ./evals/lint-skills-test.sh

Validates:
- All skill directories exist with SKILL.md files
- Platform-appropriate frontmatter fields
- Cross-references between skills point to existing files
- Viewport values (1280x800 desktop, 768x1024 tablet, 390x844 mobile) are consistent
- Screenote and Browser Use tool names, ledger fields, caps, and trust-boundary wording are present on both surfaces
- The Browser Use and MCP dependency pins match the shipped `.mcp.json`
- Removing a required Browser Use tool from either mirror makes lint fail

Run on every PR that touches `skills/**/*.md`, `codex-skills/**/*.md`, `.mcp.json`, or the adapter.

## Browser Use MCP Smoke

Live smoke test for the bundled Browser Use MCP server:

    bash evals/browser-use-mcp-smoke.sh

Validates the exact command, arguments, working directory, and environment from `.mcp.json`, then checks:

- Browser Use `0.13.4` plus the expected direct-control tools start
- The adapter exposes exact schemas for viewport sizing, numeric page metrics, exact scrolling, and 5000 px bounded file capture
- Desktop, tablet, and mobile dimensions are applied and verified at runtime
- A PNG is written through `browser_screenshot_to_file`
- Browser sessions are closed after the smoke

Run manually before changing browser-use capture behavior. It starts a local MCP subprocess and may install Python packages through `uv`.

## Trigger Eval Dataset

`trigger-eval-set.json` contains 14 test queries mapping to expected skill triggers. This dataset is ready for use when Claude Code provides proper skill trigger testing support (e.g., a `--dry-run` flag, skill match metadata in output, or `cc-plugin-eval` maturity).

### Why trigger evals are deferred

Tested `claude -p --output-format json` on 2025-03-10. Findings:
- Output is a flat result object — no message-level tool_use events exposed
- `--allowedTools "Skill"` does not restrict tool usage as expected
- Single query cost ~$0.38 (Opus), not viable for a 14-query eval suite
- Skills don't trigger as discrete `Skill` tool calls in headless mode

## CI Notes

- Lint evals: run on every PR (free, instant)
- Trigger evals: revisit when tooling improves
