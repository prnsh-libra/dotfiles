#!/bin/sh
set -eu

# One-way rename bridge: OMP -> Herdr only.
#
# The reverse sync (Herdr workspace.renamed -> OMP "/rename") is intentionally
# disabled so renaming a workspace does not rewrite the OMP session name.
# OMP session renames still propagate to Herdr through the
# herdr-workspace-title-sync.ts OMP extension.
exit 0
