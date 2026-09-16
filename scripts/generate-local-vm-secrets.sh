#!/usr/bin/env bash
# Generate private/local-vm secret files + optional Data Protection PFX for local-vm.
# Safe defaults match Identity apps/scripts/init-local.sh patterns (single `identity` DB).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="$ROOT/private/local-vm"
CERT_DIR="$ROOT/certs/local-vm"
ENV_FILE="$ROOT/environments/local-vm/.env"

mkdir -p "$DIR" "$CERT_DIR"
chmod 700 "$DIR" "$CERT_DIR"

rand() { openssl rand -hex 24; }

DB_USER="${MARIADB_USER:-identity}"
DB_NAME="${MARIADB_DATABASE:-identity}"
JDBC_USER="${JDBC_USER:-cricketarchive}"

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set -a
  # Prefer values already in .env when present
  source "$ENV_FILE" || true
  set +a
  DB_USER="${MARIADB_USER:-$DB_USER}"
  DB_NAME="${MARIADB_DATABASE:-$DB_NAME}"
fi

write_secret() {
  local name="$1" value="$2"
  local path="$DIR/$name"
  if [[ -f "$path" && "${FORCE:-}" != "1" ]]; then
    # Keep non-placeholder files
    local cur
    cur="$(tr -d '\n' <"$path" || true)"
    if [[ -n "$cur" && "$cur" != "changeme" && "$cur" != changeme* ]]; then
      printf 'keep  %s (already set)\n' "$name"
      return
    fi
  fi
  printf '%s' "$value" >"$path"
  chmod 600 "$path"
  printf 'write %s\n' "$name"
}

# Passwords
ROOT_PW="${ROOT_PW:-$(rand)}"
APP_PW="${APP_PW:-$(rand)}"
DP_PW="${DP_PW:-$(rand)}"
ADMINUI_CLIENT_SECRET="${ADMINUI_CLIENT_SECRET:-Dev}"
USERNAME_POLICY_SECRET="${USERNAME_POLICY_SECRET:-$(rand)}"
JDBC_PW="${JDBC_PW:-$(rand)}"

# Connection string used by IdS + AdminUI (host = compose service name)
CONN="server=mariadb;database=${DB_NAME};user=${DB_USER};password=${APP_PW};Command Timeout=180"

write_secret mariadb_root_password "$ROOT_PW"
write_secret mariadb_password "$APP_PW"
write_secret ConnectionStrings__identity "$CONN"
write_secret IdentityConnectionString "$CONN"
write_secret IdentityServerConnectionString "$CONN"
write_secret DataProtection__Certificate__Password "$DP_PW"
write_secret AdminUIClientSecret "$ADMINUI_CLIENT_SECRET"
write_secret UsernamePolicy__Secret "$USERNAME_POLICY_SECRET"
write_secret jdbc.username "$JDBC_USER"
write_secret jdbc.password "$JDBC_PW"

# Placeholders the operator must replace with real vendor values
write_secret LicenseKey "changeme-duende-adminui-license"
write_secret Authentication__Google__ClientId "changeme-google-client-id"
write_secret Authentication__Google__ClientSecret "changeme-google-client-secret"

# Data protection PFX (password must match DataProtection__Certificate__Password)
PFX="$CERT_DIR/ids-mysql-dp.pfx"
if [[ ! -f "$PFX" || "${FORCE_PFX:-}" == "1" ]]; then
  command -v openssl >/dev/null
  tmp="$CERT_DIR/.dp-tmp-$$"
  mkdir -p "$tmp"
  openssl req -x509 -newkey rsa:2048 -nodes -days 825 \
    -keyout "$tmp/dp.key" -out "$tmp/dp.crt" \
    -subj "/CN=Identity data protection local-vm/O=KnowledgeSpike" >/dev/null 2>&1
  openssl pkcs12 -export \
    -out "$PFX" \
    -inkey "$tmp/dp.key" \
    -in "$tmp/dp.crt" \
    -passout "pass:$DP_PW"
  rm -rf "$tmp"
  chmod 600 "$PFX"
  printf 'write %s\n' "certs/local-vm/ids-mysql-dp.pfx"
else
  printf 'keep  certs/local-vm/ids-mysql-dp.pfx\n'
fi

# Remind about OIDC secret in .env
if [[ -f "$ENV_FILE" ]] && grep -q 'OIDC_CLIENT_SECRET=change-me' "$ENV_FILE" 2>/dev/null; then
  printf '\nNOTE: set OIDC_CLIENT_SECRET in %s to the ACS client secret from Identity.\n' "$ENV_FILE"
fi

cat <<EOF

Done. Secret files are in:
  $DIR

Remember:
  1. Replace LicenseKey and Google client files with real values (or disable Google in a custom image if unused).
  2. Put the same ACS OIDC client secret in environments/local-vm/.env as OIDC_CLIENT_SECRET.
  3. MariaDB will automatically create identity, cricketarchive, and cricket databases on first startup using mariadb/init/01-init-databases.sh.
  4. chmod 600 private/local-vm/* 

Generated app DB password is in private/local-vm/mariadb_password (also embedded in connection strings).
EOF
