#!/usr/bin/env bash
# =============================================================================
# Export Identity Database - Clean Baseline Template Generator
# =============================================================================
# Exports the identity database schema and seed data from local MariaDB,
# stripping machine-specific artifacts (keys, sessions, ephemeral tokens)
# and replacing hostnames/secrets with template placeholders for clean deployment.
#
# Usage:
#   ./scripts/export-identity-db.sh [source_db] [output_file]
#
# Defaults:
#   source_db:   identity-dev
#   output_file: mariadb/init/identity-baseline.template.sql
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

SOURCE_DB="${1:-identity-dev}"
OUTPUT_FILE="${2:-$PROJECT_ROOT/mariadb/init/identity-baseline.sql.template}"
BASELINE_SCHEMA="$PROJECT_ROOT/mariadb/baseline/schema.ddl"

DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-3306}"
DB_USER="${DB_USER:-root}"
DB_PASS="${DB_PASS:-}"

if [[ -z "$DB_PASS" ]]; then
    echo "ERROR: DB_PASS must be supplied through the environment or a secret file."
    exit 1
fi

echo "=========================================="
echo "Exporting clean Identity baseline"
echo "Source DB: $SOURCE_DB on $DB_HOST:$DB_PORT"
echo "Output:    $OUTPUT_FILE"
echo "=========================================="

# Check client tools
if command -v mariadb-dump >/dev/null 2>&1; then
    DUMP_TOOL="mariadb-dump"
elif command -v mysqldump >/dev/null 2>&1; then
    DUMP_TOOL="mysqldump"
else
    echo "ERROR: mariadb-dump or mysqldump not found"
    exit 1
fi

if command -v mariadb >/dev/null 2>&1; then
    CLI_TOOL="mariadb"
elif command -v mysql >/dev/null 2>&1; then
    CLI_TOOL="mysql"
else
    echo "ERROR: mariadb or mysql client not found"
    exit 1
fi

# Verify database connection
if ! "$CLI_TOOL" -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -e "USE \`$SOURCE_DB\`;" >/dev/null 2>&1; then
    echo "ERROR: Cannot connect to database '$SOURCE_DB' on $DB_HOST:$DB_PORT"
    exit 1
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

SCHEMA_FILE="$TMP_DIR/schema.sql"
DATA_FILE="$TMP_DIR/data.sql"

if [ -f "$BASELINE_SCHEMA" ]; then
    echo "→ Using canonical baseline schema: $BASELINE_SCHEMA"
    cp "$BASELINE_SCHEMA" "$SCHEMA_FILE"
else
    echo "→ Exporting schema DDL from source DB..."
    "$DUMP_TOOL" -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" \
        --no-data \
        --skip-comments \
        --skip-dump-date \
        --single-transaction \
        "$SOURCE_DB" > "$SCHEMA_FILE"
fi

# Tables containing seed/configuration data to export
DATA_TABLES=(
    ApiResources
    ApiResourceClaims
    ApiResourceProperties
    ApiResourceScopes
    ApiScopes
    ApiScopeClaims
    ApiScopeProperties
    IdentityResources
    IdentityResourceClaims
    IdentityResourceProperties
    ExtendedApiResources
    ExtendedIdentityResources
    ExtendedClients
    Clients
    ClientGrantTypes
    ClientScopes
    ClientClaims
    ClientProperties
    ClientIdPRestrictions
    ClientSecrets
    ClientRedirectUris
    ClientPostLogoutRedirectUris
    ClientCorsOrigins
    AspNetUsers
    AspNetRoles
    AspNetUserRoles
    AspNetRoleClaims
    AspNetUserClaims
    AspNetUserLogins
    AspNetUserTokens
    ConfigurationEntries
)

echo "→ Exporting application data..."
"$DUMP_TOOL" -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" \
    --no-create-info \
    --skip-comments \
    --skip-dump-date \
    --complete-insert \
    --single-transaction \
    "$SOURCE_DB" "${DATA_TABLES[@]}" > "$DATA_FILE"

echo "→ Sanitizing data and generating clean template..."
python3 - << 'EOF' "$SCHEMA_FILE" "$DATA_FILE" "$OUTPUT_FILE"
import sys
import re

schema_path = sys.argv[1]
data_path = sys.argv[2]
output_path = sys.argv[3]

with open(schema_path, 'r', encoding='utf-8') as f:
    schema_sql = f.read()

with open(data_path, 'r', encoding='utf-8') as f:
    data_sql = f.read()

# Collect all table names created in the schema
tables_created = re.findall(r'CREATE TABLE\s+`([^`]+)`', schema_sql)

# Remove any individual DROP TABLE IF EXISTS from schema_sql so we can drop all upfront
cleaned_schema_lines = []
for line in schema_sql.splitlines():
    if line.strip().startswith("DROP TABLE IF EXISTS"):
        continue
    # Strip any lines that re-enable foreign keys prematurely
    if "FOREIGN_KEY_CHECKS" in line:
        continue
    cleaned_schema_lines.append(line)
cleaned_schema = "\n".join(cleaned_schema_lines)

out = []
out.append("-- =============================================================================")
out.append("-- Identity Database Clean Baseline Seed Template")
out.append("-- Generated automatically by scripts/export-identity-db.sh")
out.append("-- =============================================================================")
out.append("SET FOREIGN_KEY_CHECKS=0;")
out.append("SET SQL_MODE='NO_AUTO_VALUE_ON_ZERO';")
out.append("")

# Upfront clean drops for all tables in one statement
if tables_created:
    drop_list = ", ".join(f"`{t}`" for t in tables_created)
    out.append("-- -----------------------------------------------------------------------------")
    out.append("-- 1. Drop existing tables upfront (safe for clean or re-import)")
    out.append("-- -----------------------------------------------------------------------------")
    out.append(f"DROP TABLE IF EXISTS {drop_list};")
    out.append("")

# Include cleaned schema DDL
out.append("-- -----------------------------------------------------------------------------")
out.append("-- 2. Schema DDL")
out.append("-- -----------------------------------------------------------------------------")
out.append(cleaned_schema)
out.append("")

# EF Migrations History: ensure 18 target migrations expected by modern AdminUI / IdentityServer
out.append("-- -----------------------------------------------------------------------------")
out.append("-- 3. EF Core Migrations History")
out.append("-- -----------------------------------------------------------------------------")
out.append("DELETE FROM `__EFMigrationsHistory`;")
out.append("INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`) VALUES")
out.append("('20171026082841_InitialMySqlExtendedConfigurationDbMigration', '9.0.8'),")
out.append("('20180725083018_ConfigurationEntries', '9.0.8'),")
out.append("('20181205164929_ExtendedDataMigration2.3', '9.0.8'),")
out.append("('20181220155839_InitalMySqlAuditDbMigration', '9.0.8'),")
out.append("('20190305133042_MySqlSaml2PInitial', '9.0.8'),")
out.append("('20190305133541_MySqlWsfederationInitial', '9.0.8'),")
out.append("('20190321122253_ClientType', '9.0.8'),")
out.append("('20200225105251_Added AllowIdpInitiated', '9.0.8'),")
out.append("('20200626132027_InitialMySqlDataProtectionKeyMigration', '9.0.8'),")
out.append("('20200914074711_RskSamlV3', '9.0.8'),")
out.append("('20220112145727_RskSamlPackageUpdate', '9.0.8'),")
out.append("('20220114164323_MySqlSamlArtifactInitialMigration', '9.0.8'),")
out.append("('20250716072259_ConfigurationDbMigration', '9.0.9'),")
out.append("('20250716072320_PersistedGrantDbMigration', '9.0.9'),")
out.append("('20250716073046_ApplicationDbMigration', '9.0.9'),")
out.append("('20260910123954_AddApplicationRoleDescription', '9.0.9'),")
out.append("('20260910124130_AddApplicationRoleReserved', '9.0.9'),")
out.append("('20260910124613_IdentityExpressSchema', '9.0.9');")
out.append("")

out.append("-- -----------------------------------------------------------------------------")
out.append("-- 4. Application & Seed Data")
out.append("-- -----------------------------------------------------------------------------")

custom_tables = {
    'ClientSecrets',
    'ClientRedirectUris',
    'ClientPostLogoutRedirectUris',
    'ClientCorsOrigins'
}

statements = re.split(r';\s*\n', data_sql)
for stmt in statements:
    stmt = stmt.strip()
    if not stmt:
        continue

    # Strip premature foreign key re-enabling
    if "FOREIGN_KEY_CHECKS" in stmt:
        continue

    # Skip custom handled tables
    skip = False
    for ct in custom_tables:
        if f"INSERT INTO `{ct}`" in stmt:
            skip = True
            break
    if skip:
        continue

    # Template Clients table: replace ClientUri and LogoUri with placeholders
    if "INSERT INTO `Clients`" in stmt:
        stmt = stmt.replace("'https://cricket.knowledgespike.local'", "'{{WEB_URL}}'")
        stmt = stmt.replace("'https://cricket.knowledgespike.local/KnowledgeSpikeLogo.png'", "'{{WEB_URL}}/KnowledgeSpikeLogo.png'")
        stmt = stmt.replace("'https://bbb.knowledgespike.local'", "'{{BBB_WEB_URL}}'")
        stmt = stmt.replace("'https://bbb.knowledgespike.local/KnowledgeSpikeLogo.png'", "'{{BBB_WEB_URL}}/KnowledgeSpikeLogo.png'")

    out.append(stmt + ";")

out.append("")
out.append("-- -----------------------------------------------------------------------------")
out.append("-- 5. Parameterized Client Credentials & URIs")
out.append("-- -----------------------------------------------------------------------------")

# ClientSecrets
out.append("DELETE FROM `ClientSecrets`;")
out.append("INSERT INTO `ClientSecrets` (`ClientId`, `Description`, `Value`, `Expiration`, `Type`, `Created`)")
out.append("SELECT `Id`, 'AdminUI Client Secret', '{{ADMINUI_SECRET_HASH}}', NULL, 'SharedSecret', NOW() FROM `Clients` WHERE `ClientId` = 'admin_ui';")
out.append("INSERT INTO `ClientSecrets` (`ClientId`, `Description`, `Value`, `Expiration`, `Type`, `Created`)")
out.append("SELECT `Id`, 'ACS Web Client Secret', '{{ACS_SECRET_HASH}}', NULL, 'SharedSecret', NOW() FROM `Clients` WHERE `ClientId` = 'acsstats';")
out.append("INSERT INTO `ClientSecrets` (`ClientId`, `Description`, `Value`, `Expiration`, `Type`, `Created`)")
out.append("SELECT `Id`, 'BBB Web Client Secret', '{{BBB_SECRET_HASH}}', NULL, 'SharedSecret', NOW() FROM `Clients` WHERE `ClientId` = 'ballbyball';")
out.append("")

# ClientRedirectUris
out.append("DELETE FROM `ClientRedirectUris`;")
out.append("INSERT INTO `ClientRedirectUris` (`ClientId`, `RedirectUri`)")
out.append("SELECT `Id`, '{{ADMINUI_URL}}/signin-oidc' FROM `Clients` WHERE `ClientId` = 'admin_ui';")
out.append("INSERT INTO `ClientRedirectUris` (`ClientId`, `RedirectUri`)")
out.append("SELECT `Id`, '{{WEB_URL}}/signin-oidc' FROM `Clients` WHERE `ClientId` = 'acsstats';")
out.append("INSERT INTO `ClientRedirectUris` (`ClientId`, `RedirectUri`)")
out.append("SELECT `Id`, '{{BBB_WEB_URL}}/signin-oidc' FROM `Clients` WHERE `ClientId` = 'ballbyball';")
out.append("")

# ClientPostLogoutRedirectUris
out.append("DELETE FROM `ClientPostLogoutRedirectUris`;")
out.append("INSERT INTO `ClientPostLogoutRedirectUris` (`ClientId`, `PostLogoutRedirectUri`)")
out.append("SELECT `Id`, '{{ADMINUI_URL}}' FROM `Clients` WHERE `ClientId` = 'admin_ui';")
out.append("INSERT INTO `ClientPostLogoutRedirectUris` (`ClientId`, `PostLogoutRedirectUri`)")
out.append("SELECT `Id`, '{{ADMINUI_URL}}/signout-callback-oidc' FROM `Clients` WHERE `ClientId` = 'admin_ui';")
out.append("INSERT INTO `ClientPostLogoutRedirectUris` (`ClientId`, `PostLogoutRedirectUri`)")
out.append("SELECT `Id`, '{{WEB_URL}}/signout-callback-oidc' FROM `Clients` WHERE `ClientId` = 'acsstats';")
out.append("INSERT INTO `ClientPostLogoutRedirectUris` (`ClientId`, `PostLogoutRedirectUri`)")
out.append("SELECT `Id`, '{{WEB_URL}}/' FROM `Clients` WHERE `ClientId` = 'acsstats';")
out.append("INSERT INTO `ClientPostLogoutRedirectUris` (`ClientId`, `PostLogoutRedirectUri`)")
out.append("SELECT `Id`, '{{BBB_WEB_URL}}/signout-callback-oidc' FROM `Clients` WHERE `ClientId` = 'ballbyball';")
out.append("INSERT INTO `ClientPostLogoutRedirectUris` (`ClientId`, `PostLogoutRedirectUri`)")
out.append("SELECT `Id`, '{{BBB_WEB_URL}}/' FROM `Clients` WHERE `ClientId` = 'ballbyball';")
out.append("")

# ClientCorsOrigins
out.append("DELETE FROM `ClientCorsOrigins`;")
out.append("INSERT INTO `ClientCorsOrigins` (`ClientId`, `Origin`)")
out.append("SELECT `Id`, '{{ADMINUI_URL}}' FROM `Clients` WHERE `ClientId` = 'admin_ui';")
out.append("INSERT INTO `ClientCorsOrigins` (`ClientId`, `Origin`)")
out.append("SELECT `Id`, '{{WEB_URL}}' FROM `Clients` WHERE `ClientId` = 'acsstats';")
out.append("INSERT INTO `ClientCorsOrigins` (`ClientId`, `Origin`)")
out.append("SELECT `Id`, '{{BBB_WEB_URL}}' FROM `Clients` WHERE `ClientId` = 'ballbyball';")
out.append("")

out.append("SET FOREIGN_KEY_CHECKS=1;")
out.append("")

with open(output_path, 'w', encoding='utf-8') as f:
    f.write("\n".join(out))

print(f"✓ Successfully wrote sanitized template to {output_path}")
EOF

chmod 644 "$OUTPUT_FILE"
echo "=========================================="
echo "Export complete: $(du -h "$OUTPUT_FILE" | cut -f1)"
echo "=========================================="
