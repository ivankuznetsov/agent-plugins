# OpenClaw plugin API compatibility metadata

Generated package metadata now declares `openclaw.compat.pluginApi` for every
plugin, using the OpenClaw version recorded by the four-host contract as the
conservative API floor. Patch releases update all five immutable ClawHub
packages, and regression coverage prevents the compatibility field from being
omitted again.
