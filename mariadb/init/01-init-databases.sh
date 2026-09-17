#!/bin/bash
# =============================================================================
# Automatic MariaDB database & user initialization on first volume creation.
# MariaDB runs scripts in /docker-entrypoint-initdb.d/ when the data volume is empty.
# =============================================================================
set -eo pipefail

# Read passwords from mounted Docker secrets
APP_PASSWORD=$(cat /run/secrets/mariadb_password 2>/dev/null || echo "changeme")
JDBC_PASSWORD=$(cat /run/secrets/jdbc.password 2>/dev/null || echo "changeme")
JDBC_USER=$(cat /run/secrets/jdbc.username 2>/dev/null || echo "cricketarchive")
ROOT_PASSWORD=$(cat /run/secrets/mariadb_root_password 2>/dev/null || echo "")

echo "==> Initializing application databases: identity, cricketarchive, cricket..."

# Determine MariaDB client connection command:
# 1. Try passwordless connection (works during entrypoint init before root password is enforced)
# 2. If passwordless fails, connect using the mounted root password secret
MARIADB_CMD=(mariadb -uroot)
if ! mariadb -uroot -e "SELECT 1" >/dev/null 2>&1; then
    if [ -n "$ROOT_PASSWORD" ]; then
        MARIADB_CMD=(mariadb -uroot -p"$ROOT_PASSWORD")
    fi
fi

"${MARIADB_CMD[@]}" <<EOSQL
    -- 1. Identity database (IdentityServer and AdminUI)
    CREATE DATABASE IF NOT EXISTS \`identity\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    CREATE USER IF NOT EXISTS 'identity'@'%' IDENTIFIED BY '${APP_PASSWORD}';
    GRANT ALL PRIVILEGES ON \`identity\`.* TO 'identity'@'%';

    -- 2. CricketArchive database (ACS API)
    CREATE DATABASE IF NOT EXISTS \`cricketarchive\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    CREATE USER IF NOT EXISTS '${JDBC_USER}'@'%' IDENTIFIED BY '${JDBC_PASSWORD}';
    GRANT ALL PRIVILEGES ON \`cricketarchive\`.* TO '${JDBC_USER}'@'%';

    -- 3. Cricket database (future apps / cricket statistics)
    CREATE DATABASE IF NOT EXISTS \`cricket\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    GRANT ALL PRIVILEGES ON \`cricket\`.* TO 'identity'@'%';
    GRANT ALL PRIVILEGES ON \`cricket\`.* TO '${JDBC_USER}'@'%';

    FLUSH PRIVILEGES;
EOSQL

echo "==> Application databases created successfully."
