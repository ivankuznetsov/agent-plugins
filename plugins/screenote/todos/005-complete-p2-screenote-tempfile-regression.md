---
name: Replace fixed /tmp paths in /screenote with mktemp -d (match /snapshot)
description: /screenote uses fixed `/tmp/screenote-{viewport}.png` paths, exposing a symlink-attack surface and concurrent-run collisions that /snapshot already avoids via mktemp.
type: task
status: complete
priority: p2
issue_id: "005"
tags: [code-review, security, quality]
dependencies: []
---

## Problem Statement

`skills/screenote/SKILL.md:114,118,136` uses fixed paths:

```bash
filename: /tmp/screenote-{viewport}.png
...
curl ... --data-binary @/tmp/screenote-{viewport}.png ...
...
rm -f /tmp/screenote-desktop.png /tmp/screenote-tablet.png /tmp/screenote-mobile.png
```

`skills/snapshot/SKILL.md:221` does the right thing:

```bash
SNAP_DIR=$(mktemp -d /tmp/screenote-snapshot-XXXXXX)
```

Issues with the fixed path:

1. **Symlink attack**: on a multi-user host, an attacker pre-creates `/tmp/screenote-desktop.png` → `~/.ssh/id_rsa`. The screenshot overwrites the key; worse, the subsequent `curl --data-binary @…` PUTs the key contents to a URL the MCP server supplied.
2. **Concurrent run collision**: two `/screenote` invocations in parallel tabs clobber each other's files.
3. **Cleanup asymmetry**: the `rm -f` lists all three viewports even in single-viewport mode — unnecessary but also a signal the author didn't think about per-mode state.

## Findings

- The regression is from the pre-PR state: old screenote also used fixed paths, but single-viewport made collisions less likely. Multi-viewport makes this more critical (three files, higher surface).

## Proposed Solutions

### Option A (recommended) — Use mktemp in /screenote

Mirror /snapshot:

```bash
SCREENOTE_DIR=$(mktemp -d /tmp/screenote-XXXXXX)
# screenshot: $SCREENOTE_DIR/<viewport>.png
# curl: --data-binary @"$SCREENOTE_DIR/<viewport>.png"
# cleanup: rm -rf "$SCREENOTE_DIR"
```

- Pros: matches /snapshot pattern; closes symlink/collision issues.
- Cons: none.
- Effort: Small.
- Risk: None.

## Recommended Action

Option A.

## Technical Details

- **Affected files:** `skills/screenote/SKILL.md` (lines ~114, 118, 136)

## Acceptance Criteria

- [ ] /screenote creates a per-invocation temp dir via `mktemp -d`
- [ ] All subsequent filename references use the mktemp dir
- [ ] Cleanup removes the mktemp dir regardless of mode

## Work Log

_(empty)_

## Resources

- PR: https://github.com/ivankuznetsov/claude-screenote/pull/5
