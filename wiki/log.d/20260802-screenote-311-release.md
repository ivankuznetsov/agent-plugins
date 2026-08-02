# Screenote 3.1.1 release

Prepared Screenote plugin 3.1.1 for the manifest-backed viewport grouping
shipped after 3.1.0. Desktop, tablet, and mobile captures for one logical screen
now publish in a single resumable snapshot and render behind one viewport
switcher. Existing-image uploads retain the browser-free path, accept explicit
commit provenance outside Git worktrees, and preserve private recovery
artifacts on timeout or malformed terminal output.

The release keeps the contract-owned version, Claude and Codex manifests,
marketplaces, generated Pi/OpenClaw packages, semantic lock, and changelog in
sync. Offline package validation, all four native discovery gates, and the
protected Screenote integration are release requirements before tagging.
