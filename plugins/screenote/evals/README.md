# Evaluations

## Structural linting

Deterministic checks on the single shared Claude Code and Codex skill surface:

```bash
./evals/lint-skills.sh
./evals/lint-skills-test.sh
```

These checks require Bash, grep, jq, and Python 3. They validate:

- all three skills and shared CLI/OAuth/capture contract;
- canonical desktop, tablet, and mobile dimensions;
- complete CLI commands, pagination, logical viewport grouping, and safe crop
  fallback;
- exact Browser Use dependency pins, adapter files, tool names, limits, ledger,
  cleanup, and untrusted-page rules;
- a browser-only `.mcp.json`, with no Screenote HTTP MCP transport;
- shared skill discovery for Claude Code and Codex, with no mirror directory;
- plugin/marketplace schemas and trigger fixtures.

The negative fixture test proves that capture-tool drift or reintroducing a
Screenote HTTP MCP server makes lint fail.

## Portable schema validation

```bash
./evals/validate-plugin.py
```

This standard-library-only validator checks manifests, marketplace paths,
frontmatter, the exact capture-only MCP configuration, adapter assets, and the
trigger dataset without relying on machine-local Codex or Claude validators.

## Browser Use MCP smoke

Live smoke test for the bundled capture-only Browser Use server:

```bash
bash evals/browser-use-mcp-smoke.sh
```

It launches the exact command and environment from `.mcp.json`, may resolve
pinned packages through `uv`, starts a local fixture, and verifies:

- Browser Use `0.13.4` and MCP `1.26.0` start;
- exact schemas for sizing, numeric metrics, scrolling, and bounded file
  capture;
- desktop, tablet, and mobile dimensions apply exactly;
- a 390×5000 PNG is written and reports the cap;
- browser sessions close after the smoke.

Run it manually before changing capture behavior. It requires Python 3.11+,
`uv`, and Chromium/Chrome.

## Trigger eval dataset

`trigger-eval-set.json` contains test queries mapped to expected skills plus
non-triggering controls. Live language-model trigger evaluation remains
deferred until the host exposes stable, low-cost skill match metadata.

## CI notes

- Portable schema, structural lint, and negative lint fixtures run on every
  Screenote plugin change.
- The live browser smoke remains manual because it installs a browser runtime.
