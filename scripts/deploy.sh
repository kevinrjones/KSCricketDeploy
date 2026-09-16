#!/usr/bin/env bash
# =============================================================================
# Deploy Script - Pull images and start services
# =============================================================================
# Usage: ./scripts/deploy.sh [environment]
#   environment: beta or local-vm (defaults to the parent directory name)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Determine environment from argument or current directory
ENV="${1:-$(basename "$(pwd)")}"
ENV_DIR="$PROJECT_ROOT/environments/$ENV"

if [ ! -f "$ENV_DIR/compose.yaml" ]; then
    echo "ERROR: Environment '$ENV' not found at $ENV_DIR/compose.yaml"
    echo "Available environments:"
    ls -1 "$PROJECT_ROOT/environments/" 2>/dev/null || echo "  (none)"
    exit 1
fi

echo "=========================================="
echo "Deploying environment: $ENV"
echo "=========================================="

cd "$ENV_DIR"

# 1. Pull latest images
echo ""
echo "→ Pulling images..."
docker compose pull

# 2. Stop old containers gracefully
echo ""
echo "→ Stopping old containers..."
docker compose down --timeout 30

# 3. Start new containers
echo ""
echo "→ Starting services..."
docker compose up -d

# 4. Wait for health checks
echo ""
echo "→ Waiting for services to become healthy..."
echo "  (This may take a few minutes on first run)"

# Poll health status
MAX_WAIT=300  # 5 minutes
ELAPSED=0
INTERVAL=5

while [ $ELAPSED -lt $MAX_WAIT ]; do
    UNHEALTHY=$(docker compose ps --format json 2>/dev/null | \
        jq -r 'select(.Health == "unhealthy" or .Health == "starting") | .Service' 2>/dev/null || true)
    
    if [ -z "$UNHEALTHY" ]; then
        echo ""
        echo "✓ All services are healthy!"
        echo ""
        echo "Service status:"
        docker compose ps
        exit 0
    fi
    
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
    echo -n "."
done

echo ""
echo "⚠ Some services did not become healthy within $MAX_WAIT seconds."
echo "Check logs:"
echo "  docker compose -f $ENV_DIR/compose.yaml logs"
echo ""
echo "Service status:"
docker compose ps
exit 1
