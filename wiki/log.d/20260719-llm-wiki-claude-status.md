# LLM Wiki preserves Claude Code's built-in status command

Renamed the canonical LLM Wiki status skill to `wiki-status`. Claude Code had
accepted the unqualified plugin skill name `status`, causing plain `/status` to
start `/llm-wiki:status` instead of opening Claude's built-in status screen.
The collision-safe name is shared across Claude Code, Codex, Pi, and OpenClaw.
