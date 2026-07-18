# Agent SEO 2.0 migration

Agent SEO 2.0 turns the legacy `scrub` surface into a read-only formatting
audit. This is a major release because the 1.x CLI and Ruby helper transformed
content and could write files.

## CLI changes

- `seo-scrub --file article.md` prints a human-readable audit to stdout and
  never prints cleaned or rewritten content.
- `seo-scrub --file article.md --json` returns aggregate counts plus a
  `findings` array. Each finding contains `kind`, `codepoint`, and one-based
  `line` and `column` values.
- `--stats` remains accepted for command-line compatibility; the default human
  report already includes the statistics.
- `--output` returns exit status 2 with a read-only migration message. It never
  creates or changes the requested path.
- File input accepts regular `.md` and `.markdown` files only. Missing paths,
  directories, other extensions, and symlinks are rejected without a stack
  trace. Piped stdin remains supported.

Example JSON:

```json
{
  "format_controls_detected": 1,
  "emdashes_detected": 1,
  "findings": [
    {
      "kind": "format_control",
      "codepoint": "U+200B",
      "line": 1,
      "column": 7
    },
    {
      "kind": "em_dash",
      "codepoint": "U+2014",
      "line": 1,
      "column": 8
    }
  ],
  "content_changed": false
}
```

Automation that previously redirected cleaned content or parsed the 1.x
`content`/`stats`/`changes_made` envelope must switch to the audit schema. Make
editorial changes in a separate, explicitly authorized step.

## Ruby API changes

- `ContentScrubber#scrub` returns the original text plus the audit statistics.
- `ContentScrubber.scrub_content` returns the original text unchanged.
- `ContentScrubber.scrub_file` validates a Markdown path, never writes it, and
  returns audit statistics. Passing `output_path:` raises `ArgumentError`.
- Legacy mutation counters are removed. Use `format_controls_detected`,
  `emdashes_detected`, `findings`, and `content_changed`.

## Data-source configuration

Agent SEO no longer auto-loads `data_sources/config/.env`. Export the required
environment variables through a protected process environment or secret
manager. Keep unavoidable credential files outside the repository with mode
`0600`; see `data-sources-setup.md`.
