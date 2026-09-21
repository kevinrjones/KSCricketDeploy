#!/usr/bin/env bash
# =============================================================================
# Import Ball-by-Ball Database - Seed / Restore acs_ball_by_ball in MariaDB
# =============================================================================
# Imports the ball-by-ball SQL dump (or gzipped dump) into MariaDB on the VM
# or VPS. Can be executed directly inside the VM, or executed from the laptop
# targeting the VM or VPS over SSH.
#
# Usage:
#   ./scripts/import-ball-by-ball-data.sh [path-to-sql-file] [environment] [options]
#
# Arguments:
#   path-to-sql-file: Path to SQL or .sql.gz dump (optional, auto-detected if omitted)
#   environment:      local-vm or beta (defaults to local-vm)
#
# Options:
#   --database <name>     Target database name (defaults to acs_ball_by_ball)
#   --remote <user@host>  Target remote host over SSH (e.g. parallels@10.211.55.7)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/import-cricket-data.sh" --database acs_ball_by_ball "$@"
