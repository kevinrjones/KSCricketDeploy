# Agent Instructions & Troubleshooting Guide

This guide provides instructions and diagnostic workflows for AI agents (and human operators) working with this repository.
It explains the secret and password architecture, highlights common container startup failure modes, and outlines exact resolution steps.

---

## 1. Target Environments: VM vs. Host Machine

- **Virtual Machine ONLY (`local-vm`)**: `./scripts/deploy.sh local-vm` and `environments/local-vm/` are for running inside a **Linux Virtual Machine ONLY**.
- **Host Machine Execution**: To run the container images directly on the host machine (laptop), `cd` to `/Users/kevinjones/Dropbox/projects/cricket/KSCricket/deploy/docker` and run `docker compose up -d --build`.
- **Beta Environment (`beta`)**: `./scripts/deploy.sh beta` is for the remote Beta VPS.

---

## 2. Golden Rule: No Passwords or Secrets in Git

- **NEVER** commit passwords, connection strings, API keys, TLS certificates, private keys, or `.env` files to git.
- The `.gitignore` file excludes:
  - `private/local-vm/*` and `private/beta/*` (only `.gitkeep` is tracked)
  - `certs/**/*`
  - `environments/**/.env` and `.env`
  - `background_scripts/credentials.env` and `background_scripts/config.env`
- Secret files under `private/` are generated locally and mounted as Docker secrets at runtime.

---

## 3. Secrets & Configuration Architecture

The deployment uses a hybrid model of Docker secrets and environment variables:

```
┌──────────────────────────────────────┐     ┌──────────────────────────────────────┐
│  environments/<env>/.env             │     │  private/<env>/<secret_name>         │
│  (Non-secret config & OIDC secrets)  │     │  (Passwords & connection strings)    │
│  - Hostnames & Image tags            │     │  - mariadb_root_password             │
│  - STATS_OIDC_CLIENT_SECRET          │     │  - mariadb_password                  │
│  - BBB_OIDC_CLIENT_SECRET            │     │  - ConnectionStrings__identity       │
│  - Optional password overrides       │     │  - jdbc.password, LicenseKey, etc.   │
└──────────────────┬───────────────────┘     └──────────────────┬───────────────────┘
                   │                                            │
                   ▼                                            ▼
         Docker Compose (.env)                        /run/secrets/* in containers
```

### Key Components

1. **Docker Compose Secrets (`/run/secrets/`)**:
   - Each file in `private/<env>/` is mounted into containers under `/run/secrets/<filename>`.
   - The entire file content is the secret value (no `KEY=` prefix).

2. **ASP.NET Core Applications (`ids`, `adminui`)**:
   - Use .NET `KeyPerFile` configuration over `/run/secrets/`.
   - Double underscores in filenames map to configuration hierarchies (e.g., `ConnectionStrings__identity` becomes `ConnectionStrings:identity`).

3. **MariaDB Database & Users**:
   - Uses `MARIADB_ROOT_PASSWORD_FILE: /run/secrets/mariadb_root_password` and `MARIADB_PASSWORD_FILE: /run/secrets/mariadb_password`.
   - Runs `mariadb/init/01-init-databases.sh` and `02-init-identity-data.sh` **ONLY ONCE** when the data volume (`vm-mariadb-data` or `beta-mariadb-data`) is initially created empty.

4. **Data Protection Certificate (`ids-mysql-dp.pfx`)**:
   - IdentityServer encrypts data protection keys using PKCS#12 certificate `certs/<env>/ids-mysql-dp.pfx`.
   - The certificate is encrypted with the password stored in `private/<env>/DataProtection__Certificate__Password`.

5. **Secret Generation Scripts**:
   - `./scripts/generate-local-vm-secrets.sh`
   - `./scripts/generate-beta-secrets.sh`
   - These scripts read optional password overrides from `environments/<env>/.env` if present, or generate secure random passwords, writing them into `private/<env>/` and creating the Data Protection certificate.

---

## 4. Top Source of Container Errors: Password Desynchronization

When containers fail to start (or become unhealthy), **password or certificate mismatch is almost always the root cause**.

### Why Password Errors Happen

1. **Persistent Volume Mismatch**:
   MariaDB initializes its user accounts (`root`, `identity`, `cricketarchive`) only on first startup of a clean data volume.
   If secrets are regenerated via `./scripts/generate-local-vm-secrets.sh` or edited while an existing volume (`vm-mariadb-data`) is present, the secret files in `private/<env>/` have **new** passwords, but MariaDB retains its **old** passwords.
   When `ids`, `adminui`, `acs-api`, or `bbb-api` start up, they read the new secret files and fail with `Access denied for user 'identity'` or `Access denied for user 'cricketarchive'`.

2. **Data Protection Certificate Password Mismatch**:
   If `DataProtection__Certificate__Password` is changed or regenerated without re-exporting `certs/<env>/ids-mysql-dp.pfx`, IdentityServer throws `CryptographicException: The certificate data cannot be read with the provided password`.

3. **Root Authentication Socket vs Password**:
   Running `mariadb -u root -p"..."` inside the container fails if the password file doesn't match the volume. Connecting via local UNIX socket (`mariadb -u root` without `-p`) allows root access inside the container without a password.

---

## 5. Agent Diagnostic Playbook

When asked to resolve container startup errors, follow this step-by-step diagnostic workflow:

### Step 1: Check Container Status & Logs
```bash
cd environments/<env> # e.g. environments/local-vm
docker compose ps
docker compose logs --tail=100 <failing_service>
```

### Step 2: Identify the Exact Error & Apply Resolution

#### Issue A: `MySqlConnector.MySqlException: Access denied for user 'identity'@'...'`
- **Symptom**: `ids` or `adminui` logs show database authentication failure.
- **Resolution Option 1 (Clean Volume Reset — Recommended for Local VM / Test Environments)**:
  ```bash
  cd environments/local-vm
  docker compose down -v
  cd ../..
  ./scripts/deploy.sh local-vm
  ```
- **Resolution Option 2 (In-Place Credential Synchronization — Preserves Database Data)**:
  Connect via local UNIX socket to update user passwords to match current secret files:
  ```bash
  cd environments/local-vm
  docker compose exec mariadb sh -c '
    mariadb -u root -e "
      ALTER USER \"root\"@\"localhost\" IDENTIFIED BY \"$(cat /run/secrets/mariadb_root_password)\";
      ALTER USER \"identity\"@\"%\" IDENTIFIED BY \"$(cat /run/secrets/mariadb_password)\";
      ALTER USER \"cricketarchive\"@\"%\" IDENTIFIED BY \"$(cat /run/secrets/jdbc.password)\";
      FLUSH PRIVILEGES;
    "
  '
  docker compose restart ids adminui acs-api bbb-api
  ```

#### Issue B: `CryptographicException: The certificate data cannot be read with the provided password`
- **Symptom**: `ids` container fails during startup or `.AddDataProtection()` initialization.
- **Resolution**: Re-synchronize Data Protection certificate and secret password:
  ```bash
  cd ~/acs-deploy # or project root
  ./scripts/generate-local-vm-secrets.sh # or generate-beta-secrets.sh
  cd environments/local-vm
  docker compose restart ids
  ```

#### Issue C: `Access denied for user 'cricketarchive'@'...'`
- **Symptom**: `acs-api` or `bbb-api` logs report access denied for database user `cricketarchive`.
- **Resolution**:
  ```bash
  cd environments/local-vm
  docker compose exec mariadb sh -c '
    mariadb -u root -e "
      ALTER USER \"cricketarchive\"@\"%\" IDENTIFIED BY \"$(cat /run/secrets/jdbc.password)\";
      FLUSH PRIVILEGES;
    "
  '
  docker compose restart acs-api bbb-api
  ```

#### Issue D: Missing Secrets or File Permission Errors
- **Symptom**: `FileNotFoundException`, Compose mount error, or container cannot read secret files.
- **Resolution**:
  Ensure secret files exist and are readable by container processes:
  ```bash
  ./scripts/generate-local-vm-secrets.sh
  chmod 755 private/local-vm certs/local-vm
  chmod 644 private/local-vm/* certs/local-vm/*
  ```

#### Issue E: Missing `.env` File
- **Symptom**: Docker Compose error: `Set IDS_IMAGE in environments/local-vm/.env`.
- **Resolution**:
  ```bash
  cp .env.example environments/local-vm/.env
  # If on local VM, ensure hostnames and image tags are set
  ```

### Step 3: Verify Database Connectivity & Container Health

Verify credentials directly from inside the MariaDB container:
```bash
cd environments/local-vm
# Verify identity user
docker compose exec mariadb sh -c \
  'mariadb -u identity -p"$(cat /run/secrets/mariadb_password)" -e "SHOW DATABASES;"'

# Verify cricketarchive user
docker compose exec mariadb sh -c \
  'mariadb -u cricketarchive -p"$(cat /run/secrets/jdbc.password)" -e "SHOW DATABASES;"'
```

Check overall health status:
```bash
docker compose ps
```

---

## 6. Summary of Key Files

| Path | Purpose | Checked into Git? |
|---|---|---|
| `environments/<env>/.env` | Runtime environment variables & hostnames | **NO** (gitignored) |
| `.env.example` | Template for environment configuration | **YES** |
| `private/<env>/<secret>` | Individual secret files mounted at `/run/secrets/` | **NO** (gitignored) |
| `private/.secret-names` | Cheatsheet of secret names and descriptions | **YES** |
| `certs/<env>/` | TLS certificates and DP PFX certificates | **NO** (gitignored) |
| `scripts/generate-*-secrets.sh` | Scripts to generate secret files & DP certificates | **YES** |
| `scripts/deploy.sh` | Deployment runner with pre-flight checks | **YES** |
| `AGENTS.md` | Agent instruction and troubleshooting guide | **YES** |
