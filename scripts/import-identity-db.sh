#!/usr/bin/env bash
# =============================================================================
# Import Identity Database - Seed / Update MariaDB with Clean Baseline Data
# =============================================================================
# Reads environment hostnames and secrets, substitutes them into the clean
# baseline template, and imports the resulting SQL into MariaDB (local Docker,
# remote VM via SSH, or direct connection).
#
# Usage:
#   ./scripts/import-identity-db.sh [environment] [options]
#
# Arguments:
#   environment: local-vm or beta (defaults to local-vm)
#
# Options:
#   --remote <user@host>  Target remote host over SSH (e.g. parallels@10.211.55.7)
#   --template <file>     Custom template file (defaults to mariadb/init/identity-baseline.template.sql)
#   --force               Force import without confirmation
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

ENV="local-vm"
REMOTE_TARGET="${SSH_TARGET:-}"
TEMPLATE_FILE="$PROJECT_ROOT/mariadb/init/identity-baseline.sql.template"
FORCE=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --remote)
            REMOTE_TARGET="$2"
            shift 2
            ;;
        --template)
            TEMPLATE_FILE="$2"
            shift 2
            ;;
        --force)
            FORCE=1
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            echo "Usage: ./scripts/import-identity-db.sh [environment] [--remote <user@host>] [--template <path>] [--force]"
            exit 1
            ;;
        *)
            ENV="$1"
            shift
            ;;
    esac
done

ENV_DIR="$PROJECT_ROOT/environments/$ENV"
PRIVATE_DIR="$PROJECT_ROOT/private/$ENV"

if [ ! -f "$ENV_DIR/compose.yaml" ]; then
    echo "ERROR: Environment '$ENV' not found at $ENV_DIR/compose.yaml"
    exit 1
fi

if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "ERROR: Template file '$TEMPLATE_FILE' not found. Run ./scripts/export-identity-db.sh first."
    exit 1
fi

echo "=========================================="
echo "Importing Identity baseline for: $ENV"
echo "Template:    $TEMPLATE_FILE"
echo "=========================================="

# 1. Load environment variables
if [ -f "$ENV_DIR/.env" ]; then
    # shellcheck disable=SC1090
    set -a
    source "$ENV_DIR/.env"
    set +a
fi

IDS_HOST="${IDS_HOSTNAME:-ids-vm.knowledgespike.cricket}"
ADMINUI_HOST="${ADMINUI_HOSTNAME:-adminui-vm.knowledgespike.cricket}"
WEB_HOST="${ACS_WEB_HOSTNAME:-${WEB_HOSTNAME:-web-vm.knowledgespike.cricket}}"
API_HOST="${ACS_API_HOSTNAME:-${API_HOSTNAME:-api-vm.knowledgespike.cricket}}"
BBB_WEB_HOST="${BBB_WEB_HOSTNAME:-bbb-vm.knowledgespike.cricket}"
BBB_API_HOST="${BBB_API_HOSTNAME:-bbb-api-vm.knowledgespike.cricket}"

# 2. Load secrets
ADMINUI_SECRET="Dev"
if [ -f "$PRIVATE_DIR/AdminUIClientSecret" ]; then
    ADMINUI_SECRET=$(tr -d '\r\n' < "$PRIVATE_DIR/AdminUIClientSecret")
fi

ACS_SECRET="${STATS_OIDC_CLIENT_SECRET:-${OIDC_CLIENT_SECRET:-2259822cf2184c8d98c719ce84fcc47e}}"
if [ -f "$PRIVATE_DIR/STATS_OIDC_CLIENT_SECRET" ]; then
    ACS_SECRET=$(tr -d '\r\n' < "$PRIVATE_DIR/STATS_OIDC_CLIENT_SECRET")
elif [ -f "$PRIVATE_DIR/OIDC_CLIENT_SECRET" ]; then
    ACS_SECRET=$(tr -d '\r\n' < "$PRIVATE_DIR/OIDC_CLIENT_SECRET")
fi

BBB_SECRET="${BBB_OIDC_CLIENT_SECRET:-2259822cf2184c8d98c719ce84fcc47e}"
if [ -f "$PRIVATE_DIR/BBB_OIDC_CLIENT_SECRET" ]; then
    BBB_SECRET=$(tr -d '\r\n' < "$PRIVATE_DIR/BBB_OIDC_CLIENT_SECRET")
fi

ROOT_PASSWORD=""
if [ -f "$PRIVATE_DIR/mariadb_root_password" ]; then
    ROOT_PASSWORD=$(tr -d '\r\n' < "$PRIVATE_DIR/mariadb_root_password")
fi

# 3. Compute SHA512 Base64 hashes
compute_sha512_b64() {
    local val="$1"
    if command -v openssl >/dev/null 2>&1; then
        printf '%s' "$val" | openssl dgst -sha512 -binary | openssl base64 | tr -d '\r\n'
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "import hashlib, base64, sys; sys.stdout.write(base64.b64encode(hashlib.sha512(sys.argv[1].encode('utf-8')).digest()).decode('utf-8'))" "$val"
    else
        echo "ERROR: Neither openssl nor python3 available to hash secrets"
        exit 1
    fi
}

ADMINUI_HASH=$(compute_sha512_b64 "$ADMINUI_SECRET")
ACS_HASH=$(compute_sha512_b64 "$ACS_SECRET")
BBB_HASH=$(compute_sha512_b64 "$BBB_SECRET")

echo "→ Target configuration:"
echo "    IDS:     https://$IDS_HOST"
echo "    AdminUI: https://$ADMINUI_HOST"
echo "    Web:     https://$WEB_HOST"
echo "    API:     https://$API_HOST"
echo "    BBB Web: https://$BBB_WEB_HOST"
echo "    BBB API: https://$BBB_API_HOST"

# 4. Render template
RENDERED_SQL=$(mktemp)
trap 'rm -f "$RENDERED_SQL"' EXIT

sed \
    -e "s|{{IDS_URL}}|https://${IDS_HOST}|g" \
    -e "s|{{ADMINUI_URL}}|https://${ADMINUI_HOST}|g" \
    -e "s|{{WEB_URL}}|https://${WEB_HOST}|g" \
    -e "s|{{API_URL}}|https://${API_HOST}|g" \
    -e "s|{{BBB_WEB_URL}}|https://${BBB_WEB_HOST}|g" \
    -e "s|{{BBB_API_URL}}|https://${BBB_API_HOST}|g" \
    -e "s|{{ADMINUI_SECRET_HASH}}|${ADMINUI_HASH}|g" \
    -e "s|{{ACS_SECRET_HASH}}|${ACS_HASH}|g" \
    -e "s|{{BBB_SECRET_HASH}}|${BBB_HASH}|g" \
    "$TEMPLATE_FILE" > "$RENDERED_SQL"

# 5. Determine target connection mode
LOCAL_CONTAINER=$(docker compose -f "$ENV_DIR/compose.yaml" ps -q mariadb 2>/dev/null || true)

if [ -n "$LOCAL_CONTAINER" ]; then
    echo "→ Found local MariaDB container ($LOCAL_CONTAINER)"
    echo "→ Importing rendered SQL into database 'identity'..."
    docker exec -i "$LOCAL_CONTAINER" mariadb -u root -p"$ROOT_PASSWORD" identity < "$RENDERED_SQL"
    echo "✓ Import complete via local Docker container!"
    exit 0
fi

# If no local container, check remote target or auto-detect for local-vm
if [ -z "$REMOTE_TARGET" ] && [ "$ENV" = "local-vm" ]; then
    # Try default VM credentials / IP if reachable
    VM_IP=$(getent hosts "$IDS_HOST" 2>/dev/null | awk '{print $1}' || true)
    if [ -z "$VM_IP" ]; then
        VM_IP=$(dscacheutil -q host -a name "$IDS_HOST" 2>/dev/null | awk '/^ip_address:/ {print $2}' || true)
    fi
    if [ -n "$VM_IP" ]; then
        if ssh -o BatchMode=yes -o ConnectTimeout=2 "parallels@$VM_IP" "true" 2>/dev/null; then
            REMOTE_TARGET="parallels@$VM_IP"
        fi
    fi
fi

if [ -n "$REMOTE_TARGET" ]; then
    echo "→ Connecting to remote host: $REMOTE_TARGET"
    REMOTE_COMPOSE="~/acs-deploy/environments/$ENV/compose.yaml"
    REMOTE_CONTAINER=$(ssh "$REMOTE_TARGET" "docker compose -f $REMOTE_COMPOSE ps -q mariadb 2>/dev/null || true")
    
    if [ -z "$REMOTE_CONTAINER" ]; then
        echo "ERROR: MariaDB container not running on $REMOTE_TARGET"
        exit 1
    fi

    echo "→ Found remote MariaDB container ($REMOTE_CONTAINER)"
    echo "→ Streaming rendered SQL over SSH into remote database 'identity'..."
    ssh "$REMOTE_TARGET" "docker exec -i $REMOTE_CONTAINER mariadb -u root -p\$(cat ~/acs-deploy/private/$ENV/mariadb_root_password) identity" < "$RENDERED_SQL"
    echo "✓ Import complete on remote host $REMOTE_TARGET!"
    exit 0
fi

echo "ERROR: Could not find a running MariaDB container locally, and no --remote target specified."
echo "Provide a remote target with: --remote <user@host>"
exit 1
