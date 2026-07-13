# Evaluations

## Structural Linting

Deterministic checks on the shared Claude and Codex skill surface — no network
calls, runs instantly. Requires Bash, grep, jq, and Python 3.

    ./evals/lint-skills.sh

Validates:
- The shared agent surface contains all three skills with valid frontmatter
- Every skill loads the shared CLI/OAuth contract
- Canonical desktop, tablet, and mobile dimensions are consistent
- Required CLI commands and headless OAuth login are documented
- Commands do not rely on shell state surviving between agent tool calls
- A missing annotation crop degrades gracefully without hiding other feedback
- Viewport variants are required to share one logical page/title
- Legacy server configuration, tool names, and manual credential flags stay absent
- Claude/Codex manifests, marketplace entries, paths, and the trigger dataset
  satisfy the repository-owned portable schema checks

Run on every PR that touches the Screenote plugin.

## Portable Schema Validation

Run the standard-library-only validator independently when changing manifests,
marketplaces, skill frontmatter, or trigger fixtures:

    ./evals/validate-plugin.py

It resolves local component paths from the same roots each marketplace uses and
does not depend on machine-local Codex or Claude validator installations.

## Trigger Eval Dataset

`trigger-eval-set.json` contains 21 test queries mapping to expected skill triggers. This dataset is ready for use when Claude Code provides proper skill trigger testing support (e.g., a `--dry-run` flag, skill match metadata in output, or `cc-plugin-eval` maturity).

### Why trigger evals are deferred

Tested `claude -p --output-format json` on 2025-03-10. Findings:
- Output is a flat result object — no message-level tool_use events exposed
- `--allowedTools "Skill"` does not restrict tool usage as expected
- Single query cost ~$0.38 (Opus), not viable for a 14-query eval suite
- Skills don't trigger as discrete `Skill` tool calls in headless mode

## CI Notes

- Schema and lint evals: run on every PR (free, instant)
- Trigger evals: revisit when tooling improves
