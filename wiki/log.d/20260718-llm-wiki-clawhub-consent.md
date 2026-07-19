# LLM Wiki separates project writes from persistent automation

LLM Wiki 0.3.0 keeps bootstrap focused on generating the requested project wiki.
Schedulers, managed Git hooks, shared-Git runtimes, and provider-backed
refreshes require a separate approval. Existing 0.2.x configs without both
consent flags remain manual.

Generated Pi/OpenClaw skills inline the canonical behavior and name their
collision-safe `wiki-*` siblings explicitly. `wiki-status` reports both consent
flags and keeps OpenClaw update checks on the recorded ClawHub, marketplace, or
local-development source.
