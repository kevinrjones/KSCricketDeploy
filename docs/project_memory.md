# Project Memory

## Task: Add api-beta SAN to Local VM SSL Certificate
- **Date/Time Completed**: 2026-09-17 13:15
- **What Was Shipped**:
  - Added `api-beta.knowledgespike.cricket` to Subject Alternative Names (SANs) in `scripts/generate-local-vm-certs.sh`.
  - Reissued `certs/local-vm/server.crt` using `--force-server` signed by the existing local Dev CA (`dev-ca.crt`).
  - Recreated `nginx` container on the VM to serve the reissued certificate.
  - Documented the requirement in `docs/local-vm-deploy.md`.
- **Key Decisions**:
  - Reissued only the server leaf certificate (`server.crt`) rather than regenerating the CA, so the laptop's existing trust of `dev-ca.crt` and the Java `cacerts` truststore remained completely valid without requiring re-import.
  - Preserved the existing Nginx routing and Docker network configuration where `api-beta.knowledgespike.cricket` was already mapped to the Nginx reverse proxy on `acs-net`.
- **Gotchas**:
  - `acs-web` operates in `KTOR_ENVIRONMENT=beta` mode on the VM and configures BFF proxy routes (`/api/battingrecords`, `/api/bowlingrecords`, etc.) to target `https://api-beta.knowledgespike.cricket/api/...`.
  - Even though Nginx listened on `server_name api-vm.knowledgespike.cricket api-beta.knowledgespike.cricket` and Docker network had alias `api-beta.knowledgespike.cricket`, Java's TLS SNI validation in `acs-web` verified the presented certificate against the requested host `api-beta.knowledgespike.cricket`. Because `server.crt` previously only contained `*-vm` names, Java failed with `No server host: api-beta.knowledgespike.cricket in the server certificate`.
- **Test Coverage Areas**:
  - Verified `openssl s_client -connect 127.0.0.1:443 -servername api-beta.knowledgespike.cricket` shows `DNS:api-beta.knowledgespike.cricket` in Subject Alternative Names.
  - Executed a Java HTTP client probe inside the running `acs-web` container connecting to `https://api-beta.knowledgespike.cricket/healthz`, confirming successful TLS handshake and `200 OK`.

## Task: Fix ACS Web 502 Bad Gateway on API Endpoints
- **Date/Time Completed**: 2026-09-17 13:10
- **What Was Shipped**:
  - Diagnosed and resolved the `502 Bad Gateway` error on `https://web-vm.knowledgespike.cricket/api/appmetadata/GetLastDateMatchesAdded` and `/api/frontpage/getlatestmatches`.
  - Re-aligned the `cricketarchive` database user credentials in MariaDB to match `private/local-vm/jdbc.password`.
  - Updated `mariadb/init/01-init-databases.sh` to include `ALTER USER` alongside `CREATE USER IF NOT EXISTS` so credentials synchronize during initialization.
  - Restarted `acs-api` (to re-initialize HikariCP connection pool with new MariaDB credentials) and `acs-web` (to flush stale cached tokens and acquire a fresh token signed by the active IdentityServer key).
  - Cleaned up defunct undecryptable signing key from `Keys` table in IdentityServer database.
- **Key Decisions**:
  - Synchronized `cricketarchive` user credentials directly within MariaDB rather than regenerating secrets, keeping host secrets and container secrets intact.
  - Added `ALTER USER` statements in `01-init-databases.sh` to prevent `CREATE USER IF NOT EXISTS` from silently ignoring password updates on existing databases.
- **Gotchas**:
  - `acs-web` serves as a BFF (Backend-for-Frontend) proxying `/api/*` to `acs-api` with an OAuth2 access token. When `acs-api` encounters a fatal database connection failure (such as HikariCP `Access denied for user 'cricketarchive'`) or JWT validation failure, `acs-web` returns `502 Bad Gateway: {"errorMessage": "Unable to connect to the API server"}`.
  - Furthermore, `acs-web` caches access tokens in memory; when IdentityServer's active signing key changes, `acs-web` must be restarted or its token refreshed to prevent `SigningKeyNotFoundException` in `acs-api`.
- **Test Coverage Areas**:
  - Tested `curl -i https://web-vm.knowledgespike.cricket/api/appmetadata/GetLastDateMatchesAdded` confirming `HTTP/1.1 200 OK` and actual timestamp payload (`2026-09-17T05:48:29`).
  - Tested `curl -i https://web-vm.knowledgespike.cricket/api/frontpage/getlatestmatches` confirming `HTTP/1.1 200 OK` with 17 matches retrieved from the `cricketarchive` database.
  - Verified `docker compose ps` shows all services (`mariadb`, `ids`, `adminui`, `acs-web`, `acs-api`, `nginx`) running and healthy.

## Task: Fix AdminUI SSL Connection to IdentityServer on Local VM
- **Date/Time Completed**: 2026-09-17 13:00
- **What Was Shipped**:
  - Re-synchronized MariaDB identity database connection strings across `ConnectionStrings__identity`, `IdentityConnectionString`, and `IdentityServerConnectionString` in `private/local-vm/`.
  - Recreated `adminui` container in `environments/local-vm` to remount the current `certs/local-vm/dev-ca.crt` inode and fresh connection strings.
  - Verified AdminUI's backend health check (`/healthcheck/checkidentityserver`) and UI health check (`/healthcheck/checkui`) both return `200 OK`.
- **Key Decisions**:
  - Maintained single source of truth for the database user password across all connection string secrets.
  - Re-bound the `dev-ca.crt` file mount into the container via container recreation so OpenSSL in .NET validates against the newly minted root CA certificate.
- **Gotchas**:
  - Docker file mounts (`certs/local-vm/dev-ca.crt:/run/certs/dev-ca.crt:ro`) bind directly to the file inode on the host filesystem. When certificates are regenerated (`rm -f dev-ca.crt` + recreate), existing running containers retain the old deleted inode until explicitly recreated with `docker compose up -d --force-recreate`.
  - AdminUI's Angular landing page calls `/healthcheck/checkidentityserver` on its own backend, which in turn performs an outbound HTTPS GET to `${AuthorityUrl}/.well-known/openid-configuration`. If the container does not trust the TLS certificate presented by nginx for `ids-vm`, the backend throws an SSL exception which AdminUI renders as `Unable to contact IdentityServer (Error connecting to https://ids-vm.knowledgespike.cricket/.well-known/openid-configuration. The SSL connection could not be established...)`.
- **Test Coverage Areas**:
  - Verified `curl --cacert certs/local-vm/dev-ca.crt -i https://adminui-vm.knowledgespike.cricket/healthcheck/checkidentityserver` returns `HTTP/1.1 200 OK`.
  - Verified AdminUI container logs report `[INF] CheckIdentityServer https://ids-vm.knowledgespike.cricket` followed by `[INF] IdentityServer is reachable`.
  - Verified all containers in `environments/local-vm` are running and healthy.

## Task: Document Browser Certificate Trust and Restart Procedures
- **Date/Time Completed**: 2026-09-17 12:50
- **What Was Shipped**:
  - Updated `docs/local-vm-deploy.md` (Step 7.2 and Troubleshooting table) with one-liner CLI command (`security add-trusted-cert`), Keychain Access GUI steps, and critical browser restart instructions.
  - Updated `README.md` quick-start section with the macOS trust command and browser restart reminder.
- **Key Decisions**:
  - Provided both the fast macOS CLI command (`sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain certs/local-vm/dev-ca.crt`) and Keychain GUI instructions so users can choose their preferred approach.
  - Highlighted that browsers cache certificate validation chains in memory, making a full quit (`Cmd + Q`) and relaunch mandatory before testing `https://*-vm.knowledgespike.cricket` endpoints.
- **Gotchas**:
  - Simply trusting the certificate in Keychain is not sufficient if the browser is already open; Chrome and Safari will continue reporting `NET::ERR_CERT_AUTHORITY_INVALID` until the browser process is restarted.
  - Bypassing the certificate warning in the browser (`thisisunsafe` / proceed unsafe) often breaks OIDC flows because modern browsers block cross-site cookies on origins deemed insecure.
- **Test Coverage Areas**:
  - Verified Markdown rendering and documentation consistency across `docs/local-vm-deploy.md` and `README.md`.

## Task: Fix OIDC Metadata Unavailable in ACS Web on Local VM
- **Date/Time Completed**: 2026-09-17 11:55
- **What Was Shipped**:
  - Configured Java truststore (`cacerts`) generation including the local `dev-ca.crt` in `scripts/generate-local-vm-certs.sh`.
  - Mounted the custom `cacerts` into JVM-based containers (`acs-web` and `acs-api`) at `/opt/java/openjdk/lib/security/cacerts:ro` in `environments/local-vm/compose.yaml`.
  - Added `.gitignore` rules for `cacerts` and `*.p12` files.
  - Documented cause and solution in `docs/local-vm-deploy.md` and `README.md`.
- **Key Decisions**:
  - Mounted the keystore directly over Java's standard `/opt/java/openjdk/lib/security/cacerts` path rather than relying on `JAVA_TOOL_OPTIONS`, avoiding noisy JVM startup banners and ensuring all Java network operations automatically trust the local Dev CA alongside global root CAs.
  - Updated both `acs-web` (which initiates OIDC metadata discovery on `/bff/login`) and `acs-api` (which fetches JWKS keys from `ids-vm`).
- **Gotchas**:
  - .NET applications like AdminUI use OpenSSL and respect `SSL_CERT_FILE: /run/certs/dev-ca.crt`, but JVM applications completely ignore `SSL_CERT_FILE` and require a Java keystore (`cacerts` or PKCS12 truststore).
- **Test Coverage Areas**:
  - Verified `curl -k -i https://web-vm.knowledgespike.cricket/bff/login` returns `302 Found` with valid redirect to `ids-vm.knowledgespike.cricket/connect/authorize` instead of `502 Bad Gateway` / `oidc_metadata_unavailable`.
  - Verified `acs-web` and `acs-api` container health and status in `local-vm`.

## Task: Import Cricket Data into MariaDB
- **Date/Time Completed**: 2026-09-17 11:30
- **What Was Shipped**:
  - Exact command lines for importing uncompressed and gzipped cricket data dumps into MariaDB on the VM using `docker compose` or `docker exec`.
  - Helper script `scripts/import-cricket-data.sh` with automated file detection, packet size tuning, and table count verification.
  - Comprehensive documentation in `docs/local-vm-deploy.md` (Step 10) and `README.md`.
- **Key Decisions**:
  - Used `cricketarchive` as the target database name, matching `acs-api`'s configured JDBC connection (`jdbc:mariadb://mariadb:3306/cricketarchive`).
  - Read container root password dynamically via `$(cat /run/secrets/mariadb_root_password)` inside the container invocation to avoid leaking credentials or relying on hardcoded passwords.
  - Dynamically tuned `innodb_buffer_pool_size` (1 GB) and `max_allowed_packet` (1 GB / 256 MB) to ensure fast imports of the 3.1 GB / 41-million-row dataset.
- **Gotchas**:
  - Single-row inserts across 41+ million lines require high `max-allowed-packet` and sufficient InnoDB buffer pool memory to avoid timeouts or packet overflow.
  - In Docker Compose, bind mounts of secret files point to the inode created at initial start; executing the password lookup inside the container directly against `/run/secrets/mariadb_root_password` ensures 100% reliability.
- **Test Coverage Areas**:
  - Verified container root password access inside `acs-local-vm-mariadb-1`.
  - Verified table creation and sample data import (`CountryCodes`, 266 rows) into `cricketarchive` on the running VM.
  - Verified `acs-api` health endpoint `/heartbeat/alive`.
