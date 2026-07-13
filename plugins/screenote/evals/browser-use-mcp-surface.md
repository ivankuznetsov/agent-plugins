# Browser Use MCP Tool Surface

Last checked: 2026-07-13.

Sources:
- Official Browser Use MCP docs: https://docs.browser-use.com/open-source/customize/integrations/mcp-server
- Official Browser Use CLI docs: https://docs.browser-use.com/open-source/browser-use-cli
- Local smoke command: `bash evals/browser-use-mcp-smoke.sh`

## Local MCP Launch

The plugin launches the bundled adapter with `uv`; its runtime dependencies are exact pins:

```bash
uv run --with 'browser-use[cli]==0.13.4' --with 'mcp==1.26.0' \
  python -c '<load mcp/screenote_browser_use_mcp.py from the plugin root>'
```

Claude Code locates the adapter through `CLAUDE_PLUGIN_ROOT`; Codex resolves `.mcp.json`'s `cwd: "."` against the installed plugin root. The adapter sets a fresh temporary Browser Use `user_data_dir` and removes it after `browser_close_all` or server shutdown. The plugin sets `BROWSER_USE_HEADLESS=false` so manual login opens a visible Chromium window by default.

## Pinned Direct-Control Tools

The local smoke test verifies these current tool names:

- `browser_navigate`
- `browser_click`
- `browser_type`
- `browser_get_state`
- `browser_extract_content`
- `browser_get_html`
- `browser_screenshot`
- `browser_scroll`
- `browser_go_back`
- `browser_list_tabs`
- `browser_switch_tab`
- `browser_close_tab`
- `retry_with_browser_use_agent`
- `browser_list_sessions`
- `browser_close_session`
- `browser_close_all`

The adapter preserves these upstream tools and adds:

- `browser_set_viewport(width, height)`
- `browser_page_metrics()`
- `browser_scroll_to(y)`
- `browser_screenshot_to_file(path, max_height=5000)`

The live smoke requires these names and schemas, exercises all three canonical viewport sizes, and verifies a file-backed PNG. Dependency or schema drift must make the smoke fail.

## Capture Contract

The skills preflight every requested dimension before calling `create_multi_viewport_screenshot`. Normal settling consumes numeric-only metrics rather than page text. Lazy-load traversal stops at the actual bottom/no-advance condition or the 5000 px/10-scroll cap, and capture writes the first 5000 px directly to a new PNG below the system temp directory. The upstream base64 image response and overlapping tile stitching are not part of the Screenote capture path.
