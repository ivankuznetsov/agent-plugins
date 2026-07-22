# Agent Writing requires opt-in before persisting bundled context

Agent Writing 0.5.1 treats its bundled `context/` directory as read-only by
default. Editors put new anti-example candidates into the project-local review
and modify the bundled anti-example collection only after explicit user opt-in.

The change closes the persistence ambiguity reported by ClawHub's scan of the
initial 0.5.0 bundle without removing the reusable anti-example workflow.
