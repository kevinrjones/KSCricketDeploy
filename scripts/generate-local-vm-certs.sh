#!/usr/bin/env bash
# Generate a private CA and nginx server certificate for local-vm hostnames.
# Output: certs/local-vm/{dev-ca.crt,dev-ca.key,server.crt,server.key}
#
# Usage:
#   ./scripts/generate-local-vm-certs.sh
#   ./scripts/generate-local-vm-certs.sh --domain knowledgespike.cricket --days 825
#   ./scripts/generate-local-vm-certs.sh --force-server   # reissue server cert, keep CA
#   ./scripts/generate-local-vm-certs.sh --force-all      # recreate CA + server
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${ROOT_DIR}/certs/local-vm"
DOMAIN="knowledgespike.cricket"
DAYS=825
FORCE_SERVER=0
FORCE_ALL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain)
      DOMAIN="${2:?}"
      shift 2
      ;;
    --days)
      DAYS="${2:?}"
      shift 2
      ;;
    --out)
      OUT_DIR="${2:?}"
      shift 2
      ;;
    --force-server)
      FORCE_SERVER=1
      shift
      ;;
    --force-all)
      FORCE_ALL=1
      shift
      ;;
    -h|--help)
      sed -n '1,12p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

IDS_HOST="ids-vm.${DOMAIN}"
ADMINUI_HOST="adminui-vm.${DOMAIN}"
WEB_HOST="web-vm.${DOMAIN}"
API_HOST="api-vm.${DOMAIN}"
API_BETA_HOST="api-beta.${DOMAIN}"

mkdir -p "${OUT_DIR}"
cd "${OUT_DIR}"

if ! command -v openssl >/dev/null 2>&1; then
  echo "openssl is required" >&2
  exit 1
fi

if [[ "${FORCE_ALL}" -eq 1 ]]; then
  rm -f dev-ca.crt dev-ca.key dev-ca.srl server.crt server.key server.csr server-ext.cnf cacerts
fi

if [[ ! -f dev-ca.key || ! -f dev-ca.crt ]]; then
  echo "Creating local-vm Dev CA..."
  openssl genrsa -out dev-ca.key 4096
  openssl req -x509 -new -nodes -key dev-ca.key -sha256 -days "${DAYS}" \
    -out dev-ca.crt \
    -subj "/CN=KnowledgeSpike local-vm Dev CA/O=KnowledgeSpike"
  chmod 600 dev-ca.key
  chmod 644 dev-ca.crt
  rm -f cacerts
else
  echo "Reusing existing dev-ca.crt / dev-ca.key"
fi

# Generate or update Java truststore (cacerts) containing dev-ca.crt
if [[ ! -f cacerts || "${FORCE_ALL}" -eq 1 ]]; then
  echo "Generating Java truststore (cacerts) with dev-ca.crt..."
  CREATED_CACERTS=0
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    if docker run --rm -u 0 --entrypoint "" -v "${OUT_DIR}:/certs" "${ACS_WEB_IMAGE:-knowledgespike/acs-cricketarchive-web:latest}" sh -c '
      cp /opt/java/openjdk/lib/security/cacerts /certs/cacerts && \
      keytool -importcert -noprompt -alias dev-ca -file /certs/dev-ca.crt -keystore /certs/cacerts -storepass changeit && \
      chmod 644 /certs/cacerts
    ' >/dev/null 2>&1; then
      CREATED_CACERTS=1
    fi
  fi
  if [[ "${CREATED_CACERTS}" -eq 0 ]] && command -v keytool >/dev/null 2>&1; then
    BASE_CACERTS=""
    if [[ -n "${JAVA_HOME:-}" && -f "${JAVA_HOME}/lib/security/cacerts" ]]; then
      BASE_CACERTS="${JAVA_HOME}/lib/security/cacerts"
    elif [[ -f "/etc/ssl/certs/java/cacerts" ]]; then
      BASE_CACERTS="/etc/ssl/certs/java/cacerts"
    fi
    if [[ -n "${BASE_CACERTS}" ]]; then
      cp "${BASE_CACERTS}" cacerts
      chmod 644 cacerts
      keytool -importcert -noprompt -alias dev-ca -file dev-ca.crt -keystore cacerts -storepass changeit >/dev/null 2>&1 || true
    else
      keytool -importcert -noprompt -alias dev-ca -file dev-ca.crt -keystore cacerts -storepass changeit -storetype PKCS12 >/dev/null 2>&1 || true
      chmod 644 cacerts
    fi
  fi
fi

if [[ -f server.crt && -f server.key && "${FORCE_SERVER}" -eq 0 && "${FORCE_ALL}" -eq 0 ]]; then
  echo "server.crt / server.key already exist (use --force-server to reissue)"
else
  echo "Creating server certificate for:"
  echo "  ${IDS_HOST}"
  echo "  ${ADMINUI_HOST}"
  echo "  ${WEB_HOST}"
  echo "  ${API_HOST}"
  echo "  ${API_BETA_HOST}"

  openssl genrsa -out server.key 2048
  cat > server-ext.cnf <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${IDS_HOST}
DNS.2 = ${ADMINUI_HOST}
DNS.3 = ${WEB_HOST}
DNS.4 = ${API_HOST}
DNS.5 = ${API_BETA_HOST}
EOF

  openssl req -new -key server.key -out server.csr \
    -subj "/CN=${IDS_HOST}/O=KnowledgeSpike"

  openssl x509 -req -in server.csr -CA dev-ca.crt -CAkey dev-ca.key \
    -CAcreateserial -out server.crt -days "${DAYS}" -sha256 \
    -extfile server-ext.cnf

  rm -f server.csr server-ext.cnf dev-ca.srl
  chmod 600 server.key
  chmod 644 server.crt
fi

echo
echo "Wrote certificates under ${OUT_DIR}"
echo "  nginx:           server.crt + server.key"
echo "  trust on laptop: dev-ca.crt"
echo "  Java truststore: cacerts"
echo "  keep private:    dev-ca.key"
echo
echo "Next:"
echo "  1. Copy server.crt/server.key to the VM if you generated them elsewhere"
echo "  2. Trust dev-ca.crt on the laptop (see docs/local-vm-deploy.md)"
echo "  3. Add hosts entries → VM LAN IP for the four *-vm names"
echo "  4. ./scripts/deploy.sh local-vm"
