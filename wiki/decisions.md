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
the upstream minimum is unspecified.

## Screenote uses the JSON CLI only

Screenote has no alternate transport or hidden compatibility fallback. Its
launcher accepts only the seven command tuples in `plugin-surfaces.json`,
passes untrusted values as separate argv elements, and leaves credentials in
CLI-supported environment/config channels. The final annotation resolution is
a UI action until it enters the approved command contract.

## Packages are plain self-contained directories

Adapters, scripts, agents, references, context, and manifests live below the
plugin root. Symlinks and path escapes are invalid, including when they happen
to resolve in the source checkout.
