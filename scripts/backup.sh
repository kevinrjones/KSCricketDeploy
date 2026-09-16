#!/usr/bin/env bash
# =============================================================================
# Backup Script - Backup MariaDB databases
# =============================================================================
# Usage: ./scripts/backup.sh [output_directory] [environment]
#   output_directory: Where to store backups (defaults to ./backups)
#   environment: beta or local-vm (defaults to beta)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

OUTPUT_DIR="${1:-$PROJECT_ROOT/backups}"
ENV="${2:-beta}"
ENV_DIR="$PROJECT_ROOT/environments/$ENV"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="$OUTPUT_DIR/mariadb-${ENV}-${TIMESTAMP}.sql.gz"

# Create output directory if needed
mkdir -p "$OUTPUT_DIR"

echo "=========================================="
echo "Backing up MariaDB for: $ENV"
echo "Output: $BACKUP_FILE"
echo "=========================================="

# Find the MariaDB container
CONTAINER=$(docker compose -f "$ENV_DIR/compose.yaml" ps -q mariadb 2>/dev/null || true)

if [ -z "$CONTAINER" ]; then
    echo "ERROR: MariaDB container not found for environment '$ENV'"
    exit 1
fi

# Run backup
echo "→ Running mysqldump..."
docker exec "$CONTAINER" mysqldump \
    --all-databases \
    --single-transaction \
    --routines \
    --triggers \
    --events \
    --set-gtid-purged=OFF \
    | gzip > "$BACKUP_FILE"

# Verify backup
if [ -f "$BACKUP_FILE" ] && [ -s "$BACKUP_FILE" ]; then
    SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    echo "✓ Backup complete: $BACKUP_FILE ($SIZE)"
else
    echo "ERROR: Backup failed - file is empty or missing"
    exit 1
fi

# Clean up old backups (keep last 7 days)
echo "→ Cleaning up old backups..."
find "$OUTPUT_DIR" -name "mariadb-${ENV}-*.sql.gz" -mtime +7 -delete 2>/dev/null || true

echo "→ Listing recent backups:"
ls -lh "$OUTPUT_DIR"/mariadb-${ENV}-*.sql.gz 2>/dev/null || echo "  (none)"
