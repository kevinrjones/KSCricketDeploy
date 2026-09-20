#!/usr/bin/env bash
# Generate private/local-vm secret files + optional Data Protection PFX for local-vm.
# Safe defaults match Identity apps/scripts/init-local.sh patterns (single `identity` DB).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="$ROOT/private/local-vm"
CERT_DIR="$ROOT/certs/local-vm"
ENV_FILE="$ROOT/environments/local-vm/.env"

mkdir -p "$DIR" "$CERT_DIR"
chmod 755 "$DIR" "$CERT_DIR"

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
  chmod 644 "$path"
  printf 'write %s\n' "$name"
}

# Passwords (reuse existing passwords if already generated to keep secrets consistent)
if [[ -f "$DIR/mariadb_root_password" ]]; then
  existing_root="$(tr -d '\r\n' <"$DIR/mariadb_root_password" || true)"
  if [[ -n "$existing_root" && "$existing_root" != "changeme"* ]]; then
    ROOT_PW="$existing_root"
  fi
fi
ROOT_PW="${ROOT_PW:-$(rand)}"

if [[ -f "$DIR/mariadb_password" ]]; then
  existing_app="$(tr -d '\r\n' <"$DIR/mariadb_password" || true)"
  if [[ -n "$existing_app" && "$existing_app" != "changeme"* ]]; then
    APP_PW="$existing_app"
  fi
fi
APP_PW="${APP_PW:-$(rand)}"

if [[ -f "$DIR/DataProtection__Certificate__Password" ]]; then
  existing_dp="$(tr -d '\r\n' <"$DIR/DataProtection__Certificate__Password" || true)"
  if [[ -n "$existing_dp" && "$existing_dp" != "changeme"* ]]; then
    DP_PW="$existing_dp"
  fi
fi
DP_PW="${DP_PW:-$(rand)}"

if [[ -f "$DIR/jdbc.password" ]]; then
  existing_jdbc="$(tr -d '\r\n' <"$DIR/jdbc.password" || true)"
  if [[ -n "$existing_jdbc" && "$existing_jdbc" != "changeme"* ]]; then
    JDBC_PW="$existing_jdbc"
  fi
fi
JDBC_PW="${JDBC_PW:-$(rand)}"

ADMINUI_CLIENT_SECRET="${ADMINUI_CLIENT_SECRET:-Dev}"
USERNAME_POLICY_SECRET="${USERNAME_POLICY_SECRET:-$(rand)}"

# Connection string used by IdS + AdminUI (host = compose service name)
CONN="server=mariadb;database=${DB_NAME};user=${DB_USER};password=${APP_PW};Command Timeout=180"

write_secret mariadb_root_password "$ROOT_PW"
write_secret mariadb_password "$APP_PW"
# Connection strings must always match APP_PW
printf '%s' "$CONN" >"$DIR/ConnectionStrings__identity"
chmod 644 "$DIR/ConnectionStrings__identity"
printf 'write ConnectionStrings__identity\n'
printf '%s' "$CONN" >"$DIR/IdentityConnectionString"
chmod 644 "$DIR/IdentityConnectionString"
printf 'write IdentityConnectionString\n'
printf '%s' "$CONN" >"$DIR/IdentityServerConnectionString"
chmod 644 "$DIR/IdentityServerConnectionString"
printf 'write IdentityServerConnectionString\n'
write_secret DataProtection__Certificate__Password "$DP_PW"
write_secret AdminUIClientSecret "$ADMINUI_CLIENT_SECRET"
write_secret UsernamePolicy__Secret "$USERNAME_POLICY_SECRET"
write_secret jdbc.username "$JDBC_USER"
write_secret jdbc.password "$JDBC_PW"

# Placeholders the operator must replace with real vendor values
ADMINUI_LICENSE_DEFAULT="eyJleHAiOiIyMDI2LTEwLTE0VDAwOjAwOjAwLjAwMjUzODgrMDA6MDAiLCJpYXQiOiIyMDI2LTA5LTE0VDAwOjAwOjAwLjczNzY0NDhaIiwiYXVkIjoxLCJ0eXBlIjozfQ==.Klz/r1PcB+rQ9rGQZpQb7W7h7xp0TsV/VTaVfoOUWIolB8Z6/WiRSBKL5PTqikLKfwjDcx7ZCWiux7G8PeFvml7LMQ4wpfhxr9mU3JV5mjdIqlVeZ7GnqwhkxqCGkRbOv9DGVjOio9/lQ+zxOEb7dF3oI7+Az5A7cFBNYMb4RySzE6MQuuSmt1av+D02/bXKKZiuBpMtWciCthLVo/LQM4bpQqN9SUIVrJgu1Y3v2TJRrBIjkQRNrxf4C9eDwVgFhAg2izo7ByFDQNvAyDrkhV/SVajYbNIqAcGdSWpwz/gq0bECfmx3R4ezEYuJBnG11erccWoc3cxXIP713WOhHmGE6LxsHcJT1FmanOobw6VtAmHWSpSmVRqAxEXTq/85r8fcjgHQzrgrWc76zfegs7GMgwi9wuj3aHYYSrvgg9bcuNOC1JevPb5iNMTJAk07ZF7gKYt7OXKpJVhhBdpUshpHoT2VykFnqdiNPKZtwqhuaVJRoi4ZD8g3qHHxIHOmgp2q4ZOtTvZxvYMKbMX7gAOZluRQt82c3smym2yqyPXBDp/5pJ6wGrKdO9P5Ejs9yasZ15v7Ab0HsB+wn7LJryN+ERDhSYHLHzig+rlAEo6beobshhFCe/4rzkIKe1ICI16whkE7juME28NEqAm27KoahOjpbFgFZXroDJV1Wr4="
write_secret LicenseKey "${ADMINUI_LICENSE:-$ADMINUI_LICENSE_DEFAULT}"
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
  chmod 644 "$PFX"
  printf 'write %s\n' "certs/local-vm/ids-mysql-dp.pfx"
else
  printf 'keep  certs/local-vm/ids-mysql-dp.pfx\n'
fi

# Remind about OIDC secret in .env
if [[ -f "$ENV_FILE" ]] && grep -q 'STATS_OIDC_CLIENT_SECRET=change-me' "$ENV_FILE" 2>/dev/null; then
  printf '\nNOTE: set STATS_OIDC_CLIENT_SECRET in %s to the STATS client secret from Identity.\n' "$ENV_FILE"
fi
if [[ -f "$ENV_FILE" ]] && grep -q 'BBB_OIDC_CLIENT_SECRET=change-me' "$ENV_FILE" 2>/dev/null; then
  printf '\nNOTE: set BBB_OIDC_CLIENT_SECRET in %s to the BBB client secret from Identity.\n' "$ENV_FILE"
fi

cat <<EOF

Done. Secret files are in:
  $DIR

Remember:
  1. Replace LicenseKey and Google client files with real values (or disable Google in a custom image if unused).
  2. Put the same STATS OIDC client secret in environments/local-vm/.env as STATS_OIDC_CLIENT_SECRET.
  3. Put the same BBB OIDC client secret in environments/local-vm/.env as BBB_OIDC_CLIENT_SECRET.
  4. MariaDB will automatically create identity, cricketarchive, and cricket databases on first startup using mariadb/init/01-init-databases.sh.
  5. Secrets and certs must remain readable by container users (chmod 644 private/local-vm/* certs/local-vm/ids-mysql-dp.pfx).

Generated app DB password is in private/local-vm/mariadb_password (also embedded in connection strings).
EOF
