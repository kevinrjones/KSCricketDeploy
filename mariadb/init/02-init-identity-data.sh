#!/usr/bin/env bash
# =============================================================================
# Automatic MariaDB Identity Baseline Initialization on first volume creation.
# MariaDB runs scripts in /docker-entrypoint-initdb.d/ when the data volume is empty.
# This script applies the clean identity baseline data with environment-specific
# hostnames and client secret hashes.
# =============================================================================
set -eo pipefail

echo "==> Initializing identity baseline data..."

ROOT_PASSWORD=$(cat /run/secrets/mariadb_root_password 2>/dev/null || echo "")

MARIADB_CMD=(mariadb -uroot)
if ! mariadb -uroot -e "SELECT 1" >/dev/null 2>&1; then
    if [ -n "$ROOT_PASSWORD" ]; then
        MARIADB_CMD=(mariadb -uroot -p"$ROOT_PASSWORD")
    fi
fi

# Check if identity database is already initialized with users
EXISTING_TABLE=$("${MARIADB_CMD[@]}" -N -B -e "SELECT count(*) FROM information_schema.tables WHERE table_schema='identity' AND table_name='AspNetUsers';" 2>/dev/null || echo "0")
if [ "$EXISTING_TABLE" = "1" ]; then
    USER_COUNT=$("${MARIADB_CMD[@]}" -N -B -e "SELECT count(*) FROM \`identity\`.\`AspNetUsers\`;" 2>/dev/null || echo "0")
    if [ "$USER_COUNT" -gt "0" ]; then
        echo "==> Identity database already contains $USER_COUNT users. Skipping baseline import."
        exit 0
    fi
fi

TEMPLATE_FILE="/docker-entrypoint-initdb.d/identity-baseline.sql.template"
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "WARNING: Template file $TEMPLATE_FILE not found. Skipping identity baseline init."
    exit 0
fi

# Determine environment hostnames
IDS_HOST="${IDS_HOSTNAME:-ids-vm.knowledgespike.cricket}"
ADMINUI_HOST="${ADMINUI_HOSTNAME:-adminui-vm.knowledgespike.cricket}"
WEB_HOST="${WEB_HOSTNAME:-web-vm.knowledgespike.cricket}"
API_HOST="${API_HOSTNAME:-api-vm.knowledgespike.cricket}"

# Determine secrets
if [ -f /run/secrets/AdminUIClientSecret ]; then
    ADMINUI_SECRET=$(cat /run/secrets/AdminUIClientSecret | tr -d '\r\n')
else
    ADMINUI_SECRET="${ADMINUI_CLIENT_SECRET:-Dev}"
fi

if [ -f /run/secrets/OIDC_CLIENT_SECRET ]; then
    ACS_SECRET=$(cat /run/secrets/OIDC_CLIENT_SECRET | tr -d '\r\n')
else
    ACS_SECRET="${OIDC_CLIENT_SECRET:-2259822cf2184c8d98c719ce84fcc47e}"
fi

# Compute SHA512 Base64 hashes using MariaDB SQL
ADMINUI_HASH=$("${MARIADB_CMD[@]}" -N -B -e "SELECT REPLACE(TO_BASE64(UNHEX(SHA2('${ADMINUI_SECRET}', 512))), '\n', '');")
ACS_HASH=$("${MARIADB_CMD[@]}" -N -B -e "SELECT REPLACE(TO_BASE64(UNHEX(SHA2('${ACS_SECRET}', 512))), '\n', '');")

echo "==> Applying identity baseline template with hostnames:"
echo "    IDS:     https://$IDS_HOST"
echo "    AdminUI: https://$ADMINUI_HOST"
echo "    Web:     https://$WEB_HOST"
echo "    API:     https://$API_HOST"

sed \
    -e "s|{{IDS_URL}}|https://${IDS_HOST}|g" \
    -e "s|{{ADMINUI_URL}}|https://${ADMINUI_HOST}|g" \
    -e "s|{{WEB_URL}}|https://${WEB_HOST}|g" \
    -e "s|{{API_URL}}|https://${API_HOST}|g" \
    -e "s|{{ADMINUI_SECRET_HASH}}|${ADMINUI_HASH}|g" \
    -e "s|{{ACS_SECRET_HASH}}|${ACS_HASH}|g" \
    "$TEMPLATE_FILE" | "${MARIADB_CMD[@]}" identity

echo "==> Identity baseline initialization complete."
