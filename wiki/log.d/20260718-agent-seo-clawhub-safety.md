# Agent SEO narrows mutation and provenance behavior

Agent SEO 2.0.0 replaces the legacy content transformation behind `scrub` with
a read-only formatting audit. Editorial workflows preserve authorship and
provenance disclosures, create new artifacts by default, and require an
explicit request before editing an existing path.

Live analytics access now starts only from an explicit data workflow with a
declared source and scope. Credential guidance uses protected storage outside
the repository, and the ClawHub bundle excludes development-only todos/tests,
generated output, and validator reports.

The release is versioned 2.0.0 because the old scrub CLI and Ruby write
contracts are intentionally removed. The replacement audit covers Unicode
category `Cf`, reports one-based locations, rejects unsafe file inputs, and has
a dedicated migration guide and process-level regression tests.
