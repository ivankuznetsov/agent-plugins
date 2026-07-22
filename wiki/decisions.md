# Decisions

## Canonical skills and generated host adapters

Behavior stays in each plugin's existing `skills/` tree. Host-specific files
are deterministic adapters with origin and semantic hashes. Generated files
are checked in because agent caches install ordinary directory copies.

## Inventory cannot be declared away

The shipped set is the union of both root catalogs and every top-level plugin
directory. Stability and all four platform surfaces are mandatory contract
fields. Exclusions and unsupported hosts require explicit owner/reason/review
approval.

## Tested versions are not minimums

Exact CI pins prove current compatibility. A formal minimum is recorded only
when upstream evidence establishes it; otherwise the contract explicitly says
the upstream minimum is unspecified. ClawHub's package contract is narrower:
`openclaw.compat.pluginApi` uses the exact OpenClaw version each package was
built and tested against as a conservative API floor, independently of the
general host minimum.

## Screenote uses the JSON CLI only

Screenote has no alternate transport or hidden compatibility fallback. Its
launcher accepts only the seven command tuples in `plugin-surfaces.json`,
passes untrusted values as separate argv elements, and leaves credentials in
CLI-supported environment/config channels. The final annotation resolution is
a UI action until it enters the approved command contract.

Every nonzero CLI result stops the workflow. The runtime preserves the JSON
diagnostic and error code, gives specific setup guidance only for exit-2
`missing_token` / `missing_project` and exit-3 authentication failures, and
does not choose an alternative when a project is ambiguous or inaccessible.

## Agent SEO mutation and live data require explicit scope

The legacy `scrub` surface remains available as a read-only formatting audit.
Editorial workflows create new artifacts by default, preserve authorship and
provenance disclosures, and edit an existing file only when the user explicitly
requests that exact path. Analytics providers are queried only from an explicit
`data` or `performance-review` workflow with a declared source and scope.

The 1.x cleaned-text, `--output`, and in-place Ruby contracts are intentionally
removed. The replacement reports Unicode format controls and em dashes with
one-based locations and keeps credentials outside the repository.

## Packages are plain self-contained directories

Adapters, scripts, agents, references, context, and manifests live below the
plugin root. Symlinks and path escapes are invalid, including when they happen
to resolve in the source checkout.
