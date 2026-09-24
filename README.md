# ACS Deploy — Uber Deployment Repository

> **Purpose:** Single Docker Compose project to deploy Identity Server, AdminUI, ACS, and BBB services on a shared VPS or local VM behind a single edge nginx.

## Quick Start

**Laptop local VM (hosts file + private CA):** follow the full walkthrough → **[docs/local-vm-deploy.md](docs/local-vm-deploy.md)**.

**Beta / VPS (Cloudflare + public IP):** follow the full walkthrough → **[docs/beta-deploy.md](docs/beta-deploy.md)**.

**Short form (Beta):**

```bash
# 1. Clone this repo onto the VPS
git clone https://github.com/kevinrjones/KSCricketDeploy.git acs-deploy && cd acs-deploy

# 2. Environment + secrets for beta
cp .env.example environments/beta/.env
$EDITOR environments/beta/.env
# Fill private/beta/* (see Secrets)

# 3. TLS: Cloudflare origin cert → certs/beta/server.crt + server.key

# 4. Deploy
./scripts/deploy.sh beta
```

## Architecture

**Beta (Netcup VPS — public IP):**

```
Cloudflare (orange-cloud proxy)
  → nginx edge (port 443 on VPS)
    → ids / adminui / acs-web / acs-api / bbb-web / bbb-api / mariadb
```

**Local VM (laptop VM — private LAN IP only):**

```
Your laptop hosts file (or optional Cloudflare Tunnel)
  → nginx edge (port 443 on VM)
    → same services as beta
```

All services share one Docker network. nginx routes by `Host` header. Ports 80
and 443 are publicly exposed; Beta additionally binds MariaDB to loopback port
3307 for host-side maintenance runners.

> **Important:** A local VM without a public IP cannot be the target of Cloudflare A/AAAA records (proxied or DNS-only). Cloudflare’s edge must reach a **public** origin. See [DNS and local VM](#dns-and-local-vm).

## Repository Layout

```
├── README.md               # This file
├── .gitignore
├── .env.example            # Template for environment variables
├── environments/
│   ├── beta/
│   │   ├── compose.yaml    # Beta environment compose
│   │   └── .env            # Beta-specific env (gitignored)
│   └── local-vm/
│       ├── compose.yaml    # Local VM compose
│       └── .env            # Local VM env (gitignored)
├── nginx/
│   ├── beta.conf           # Beta nginx config
│   └── local-vm.conf       # Local VM nginx config
├── mariadb/
│   ├── baseline/
│   │   └── schema.ddl             # Modern EF Core 9 baseline DDL
│   └── init/
│       ├── 01-init-databases.sh   # Automated DB & user setup (identity, cricketarchive, acs_ball_by_ball, cricket)
│       ├── 02-init-identity-data.sh # Automated baseline seed on empty volume
│       └── identity-baseline.sql.template # Cleaned identity baseline template
├── certs/                  # Origin TLS certificates (gitignored)
├── scripts/
│   ├── deploy.sh                       # Deploy script (pull + up)
│   ├── backup.sh                       # MariaDB backup script
│   ├── export-identity-db.sh           # Export and clean identity baseline from local DB
│   ├── import-identity-db.sh           # Import sanitized baseline into running target
│   ├── import-cricket-data.sh          # Import CricketArchive / custom dump into MariaDB
│   ├── import-ball-by-ball-data.sh     # Import Ball-by-Ball dump into MariaDB
│   ├── generate-local-vm-certs.sh      # Private CA + nginx cert for *-vm hostnames
│   ├── generate-local-vm-secrets.sh    # DB/OIDC-related secret files + DP PFX for local-vm
│   └── generate-beta-secrets.sh        # DB/OIDC-related secret files + DP PFX for beta
├── ca_scripts/                         # CricketArchive fetch/update runners
│   ├── README.md                       # Laptop and VPS setup
│   ├── config.env.example              # Non-secret runtime configuration
│   └── credentials.env.example         # Empty credential template
├── private/                # Per-env secret *files* (gitignored bodies; see private/README.md)
│   ├── .secret-names       # Cheatsheet only (not loaded by Compose)
│   ├── README.md
│   ├── beta/
│   └── local-vm/
└── docs/
    ├── local-vm-deploy.md  # Step-by-step laptop VM: hosts, certs, deploy
    ├── beta-deploy.md      # Step-by-step remote VPS: Cloudflare, origin cert, deploy
    └── migration-notes.md  # Notes on migrating from Swarm
```

## Environments

| Environment  | Compose Project                      | Hostnames                       | How names reach the host                                                                        |
|--------------|--------------------------------------|---------------------------------|-------------------------------------------------------------------------------------------------|
| **Beta**     | `environments/beta/compose.yaml`     | `*-beta.knowledgespike.cricket` | Cloudflare orange-cloud A/AAAA → **VPS public IP**                                              |
| **Local VM** | `environments/local-vm/compose.yaml` | `*-vm.knowledgespike.cricket`   | **Hosts/split-DNS** → VM LAN IP (default), or **Cloudflare Tunnel** — **not** CF A → private IP |

Each environment has its own `.env` with hostnames, image tags, and secret paths. Compose shape stays the same; DNS/TLS front door differs.

## Image Registry

All images are published to Docker Hub by their respective app repositories:

| Service        | Image                                   | Source Repo    |
|----------------|-----------------------------------------|----------------|
| IdentityServer | `knowledgespike/ids`                    | Identity repo  |
| AdminUI        | `knowledgespike/adminui`                | Identity repo  |
| ACS Web        | `knowledgespike/acs-cricketarchive-web` | KSCricket repo |
| ACS API        | `knowledgespike/acs-cricketarchive-api` | KSCricket repo |
| BBB Web        | `knowledgespike/bbb-web`                | BBB repo       |
| BBB API        | `knowledgespike/bbb-api`                | BBB repo       |
| MariaDB        | `mariadb:11`                            | Official       |
| nginx          | `nginx:stable-alpine`                   | Official       |

### Image Tagging

Images are tagged with:
- `:latest` — most recent build
- `:v*.*.*` — semantic version tags
- `:sha-<12-char-commit>` — commit-specific tags

**Pin to `sha-` tags in production** for reproducible deployments.

## Secrets

**Two stores** (do not mix them up):

| Store | Path                       | Holds                                                                                                                       |
|-------|----------------------------|-----------------------------------------------------------------------------------------------------------------------------|
| Env   | `environments/<env>/.env`  | Image tags, hostnames, `MARIADB_DATABASE` / `MARIADB_USER`, `STATS_OIDC_CLIENT_*`, `BBB_OIDC_CLIENT_*`                      |
| Files | `private/<env>/<filename>` | Passwords, connection strings, AdminUI license, Google OAuth, and Beta IdS SMTP settings — **one value per file**, mounted at `/run/secrets/<filename>` |

- `private/.secret-names` is a **cheatsheet only** (Compose does not load it).
- `private/README.md` summarises the model.
- Full local-vm walkthrough: **[docs/local-vm-deploy.md](docs/local-vm-deploy.md)**.
- Full Beta walkthrough: **[docs/beta-deploy.md](docs/beta-deploy.md)**.
- CricketArchive fetch/update runners: **[ca_scripts/README.md](ca_scripts/README.md)**.

### Required secret files (local-vm)

| File under `private/local-vm/`                                             | Used by                                            |
|----------------------------------------------------------------------------|----------------------------------------------------|
| `mariadb_root_password`, `mariadb_password`                                | MariaDB                                            |
| `ConnectionStrings__identity`                                              | ids                                                |
| `DataProtection__Certificate__Password`                                    | ids (+ matching `certs/local-vm/ids-mysql-dp.pfx`) |
| `Authentication__Google__ClientId`, `Authentication__Google__ClientSecret` | ids                                                |
| `LicenseKey`, `AdminUIClientSecret`, `UsernamePolicy__Secret`              | adminui                                            |
| `IdentityConnectionString`, `IdentityServerConnectionString`               | adminui                                            |
| `jdbc.username`, `jdbc.password`                                           | acs-api, bbb-api                                   |

ACS Web and BBB Web client secrets are **`STATS_OIDC_CLIENT_SECRET` and `BBB_OIDC_CLIENT_SECRET` in `.env`**, not secret files.

### Additional required secret files (beta)

The Beta `ids` service mounts these SMTP settings in addition to the common
files above:

| File under `private/beta/` | Used by |
|---|---|
| `MailKit__SmtpServer`, `MailKit__Port` | ids |
| `MailKit__Username`, `MailKit__Password` | ids |

Generate the complete Beta set with:

```bash
./scripts/generate-beta-secrets.sh
# Replace MailKit__* placeholders, LicenseKey, and Google OAuth files.
```

The generator creates `smtp.gmail.com`, port `587`, and `changeme-*`
placeholders by default; replace all four values with the SMTP provider
settings before deploying Beta.

### How to set secrets (local-vm)

```bash
cp .env.example environments/local-vm/.env
# edit image tags, hostnames, STATS_OIDC_CLIENT_SECRET, BBB_OIDC_CLIENT_SECRET

./scripts/generate-local-vm-secrets.sh
# then replace LicenseKey + Google files with real values
chmod 600 private/local-vm/*
```

## TLS Certificates

nginx terminates TLS on the host. Place certificates in `certs/`:

```
certs/
├── beta/
│   ├── server.crt    # Cloudflare origin cert (or other CF-trusted origin cert)
│   └── server.key
└── local-vm/
    ├── server.crt    # Dev/self-signed or private CA (hosts path)
    └── server.key
```

### Beta + Cloudflare TLS

On the VPS path, set Cloudflare SSL/TLS mode to **Full (strict)**. Origin certificates must be trusted by Cloudflare (typically a **Cloudflare origin certificate**).

### Local VM TLS

With the default **hosts → LAN IP** path there is no Cloudflare in front of the VM:

- Run `./scripts/generate-local-vm-certs.sh` (or manual OpenSSL in the local-vm guide) so SANs cover the six `*-vm` hostnames (plus `api-beta` for local Ktor BFF proxy routing)
- Trust `dev-ca.crt` on the laptop/browser
- Do not expect Cloudflare Full (strict) to apply to this path
- Details: [docs/local-vm-deploy.md](docs/local-vm-deploy.md)

If you later use **Cloudflare Tunnel**, TLS is often terminated at Cloudflare; follow Cloudflare’s tunnel docs rather than copying the beta origin-cert setup blindly.

## Deploy Script

```bash
# Deploy beta environment
cd environments/beta
../../scripts/deploy.sh

# Deploy local-vm environment
cd environments/local-vm
../../scripts/deploy.sh
```

The script:
1. Pulls latest images
2. Stops old containers
3. Starts new containers
4. Waits for health checks

## Backup Script

```bash
# Backup MariaDB
./scripts/backup.sh <output-directory>
```

Backs up all databases to SQL dumps. Run regularly via cron.

## Identity Database Baseline & Migration

The Identity database contains users, roles, claims, clients, and API resources. To migrate data from a laptop development database without machine-specific artifacts (e.g. localhost URLs, ephemeral session tokens, host-specific encryption keys):

### 1. Export Clean Baseline from Laptop

```bash
./scripts/export-identity-db.sh [source_database] [output_file]
```
- Defaults: source `identity-dev`, output `mariadb/init/identity-baseline.sql.template`.
- Dumps users, roles, claims, client definitions, and resources while stripping ephemeral keys (`DataProtectionKeys`, `Keys`, `PersistedGrants`, `AuditEntries`).
- Replaces machine-specific URLs and client secrets with environment template placeholders (`{{IDS_URL}}`, `{{WEB_URL}}`, `{{ADMINUI_SECRET_HASH}}`, etc.).
- To run that script against the Docker MariaDB version on this machine (which should be the canonical version), supply the password outside the command history:
```bash
read -r -s -p 'MariaDB password: ' DB_PASS; printf '\n'
DB_PORT=3307 DB_USER=identity DB_PASS="$DB_PASS" \
  ./scripts/export-identity-db.sh identity mariadb/init/identity-baseline.sql.template
unset DB_PASS
```

### 2. Automatic Clean VM Installation

On first boot of a clean VM (with empty MariaDB volumes):
- MariaDB automatically executes `mariadb/init/02-init-identity-data.sh`.
- The script detects the environment hostnames and secret files (`AdminUIClientSecret`, `OIDC_CLIENT_SECRET`), computes the required SHA-512 hashes, renders the template, and seeds the database automatically before services start.

### 3. Immediate Import into Running VM

To apply the baseline data to an already running VM container immediately:

```bash
./scripts/import-identity-db.sh local-vm
```
- Reads the environment hostnames (`environments/local-vm/.env`) and secrets (`private/local-vm/`).
- Computes SHA-512 hashes and streams the rendered SQL directly into the running MariaDB container (locally or over SSH).

## Data Import (CricketArchive & Ball-by-Ball)

The application stack uses two databases for cricket information:
- **`cricketarchive`**: Match, player, team, and statistical data consumed by `acs-api`.
- **`acs_ball_by_ball`**: Dimensional delivery and match tables (`dim_match`, `dim_person`, `fact_delivery`) consumed by `bbb-api`.

### 1. Direct Command Line Import

#### Local VM

Stream SQL dumps (uncompressed or gzipped) directly into the running MariaDB container on the VM:

```bash
cd ~/acs-deploy

# CricketArchive (cricketarchive)
gunzip -c /media/psf/Dropbox/dumps/mysql/cricketarchive-upload.sql.gz | docker compose -f environments/local-vm/compose.yaml exec -T mariadb sh -c \
  'mariadb -u root -p"$(cat /run/secrets/mariadb_root_password)" --max-allowed-packet=1G cricketarchive'

# Ball-by-Ball (acs_ball_by_ball)
gunzip -c /media/psf/Dropbox/dumps/mysql/ball-by-ball-upload.sql.gz | docker compose -f environments/local-vm/compose.yaml exec -T mariadb sh -c \
  'mariadb -u root -p"$(cat /run/secrets/mariadb_root_password)" --max-allowed-packet=1G acs_ball_by_ball'
```

#### Beta (VPS)

```bash
cd ~/acs-deploy

# CricketArchive (cricketarchive)
gunzip -c /path/to/cricketarchive-upload.sql.gz | docker compose -f environments/beta/compose.yaml exec -T mariadb sh -c \
  'mariadb -u root -p"$(cat /run/secrets/mariadb_root_password)" --max-allowed-packet=1G cricketarchive'

# Ball-by-Ball (acs_ball_by_ball)
gunzip -c /path/to/ball-by-ball-upload.sql.gz | docker compose -f environments/beta/compose.yaml exec -T mariadb sh -c \
  'mariadb -u root -p"$(cat /run/secrets/mariadb_root_password)" --max-allowed-packet=1G acs_ball_by_ball'
```

### 2. Using the Import Helper Scripts

Helper scripts are provided that automatically tune packet limits, detect uncompressed or gzipped dumps, and print table verification row counts:

#### Local VM

```bash
# Inside the VM (auto-detects dumps from shared /media/psf/Dropbox/dumps/mysql/):
./scripts/import-cricket-data.sh local-vm
./scripts/import-ball-by-ball-data.sh local-vm

# From laptop targeting the VM over SSH:
./scripts/import-cricket-data.sh ~/Dropbox/dumps/mysql/cricketarchive-upload.sql.gz local-vm
./scripts/import-ball-by-ball-data.sh ~/Dropbox/dumps/mysql/ball-by-ball-upload.sql.gz local-vm
```

#### Beta (VPS)

```bash
# On the VPS host, with dumps stored in ~/sql:
./scripts/import-cricket-data.sh ~/sql/cricketarchive-upload.sql.gz beta
./scripts/import-ball-by-ball-data.sh ~/sql/ball-by-ball-upload.sql.gz beta

# Or stream dumps stored on the laptop to the VPS over SSH:
./scripts/import-cricket-data.sh ~/Dropbox/dumps/mysql/cricketarchive-upload.sql.gz beta --remote root@<vps-ip>
./scripts/import-ball-by-ball-data.sh ~/Dropbox/dumps/mysql/ball-by-ball-upload.sql.gz beta --remote root@<vps-ip>
```

The dump path is resolved on the machine running the script. A path such as
`~/sql/cricketarchive-upload.sql.gz` therefore refers to the VPS only when the
command is run from the VPS; use `--remote` when the dump is on the laptop.

## DNS and local VM

### Why local VM ≠ Cloudflare A record

A typical laptop VM has only a **private** IP. Cloudflare (orange-cloud **or** grey-cloud) cannot usefully target that address as an origin: the public internet — including Cloudflare’s network — cannot route to `192.168.x.x` / `10.x.x.x`.

| Environment        | Public IP? | Supported front door                                          |
|--------------------|------------|---------------------------------------------------------------|
| **Beta (Netcup)**  | Yes        | Cloudflare orange-cloud → VPS IP → origin nginx               |
| **Local VM (LAN)** | No         | Hosts/split-DNS → VM IP + local TLS, **or** Cloudflare Tunnel |

Compose, image pins, secrets, and Host-based nginx stay the same. Only **name resolution and TLS front door** change.

### Beta (Cloudflare)

Create A/AAAA records to the **VPS public IP** only:

| Hostname                                  | Type | Proxy            |
|-------------------------------------------|------|------------------|
| `ids-beta.knowledgespike.cricket`         | A    | Orange (proxied) |
| `adminui-beta.knowledgespike.cricket`     | A    | Orange (proxied) |
| `stats-beta.knowledgespike.cricket`       | A    | Orange (proxied) |
| `stats-api-beta.knowledgespike.cricket`   | A    | Orange (proxied) |
| `bbb-beta.knowledgespike.cricket`         | A    | Orange (proxied) |
| `bbb-api-beta.knowledgespike.cricket`     | A    | Orange (proxied) |

`web-beta` and `api-beta` remain Nginx aliases for backward compatibility, but
the `stats-*` names are the canonical Beta ACS URLs used by the deployment
guide and OIDC configuration.

### Local VM (default: hosts file)

**Full steps (VM setup, Docker, secrets, OpenSSL/CA, hosts, trust store, verify):** see **[docs/local-vm-deploy.md](docs/local-vm-deploy.md)**.

Short version:

1. Generate certs: `./scripts/generate-local-vm-certs.sh` → `certs/local-vm/server.crt|key`, `dev-ca.crt`, and Java `cacerts`.
2. Deploy `environments/local-vm` on the VM (`./scripts/deploy.sh local-vm`).
3. On the **laptop**, map names to the VM LAN IP:

```text
192.168.x.x  ids-vm.knowledgespike.cricket adminui-vm.knowledgespike.cricket web-vm.knowledgespike.cricket api-vm.knowledgespike.cricket bbb-vm.knowledgespike.cricket bbb-api-vm.knowledgespike.cricket
```

4. Trust `certs/local-vm/dev-ca.crt` on those clients (on macOS: `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain certs/local-vm/dev-ca.crt`) and **restart your browser** (`Cmd + Q`) to prevent "Your connection is not private" warnings.
5. Keep OIDC issuer/authority/redirect/CORS on the same `*-vm` hostnames end-to-end.

Optional: router or split-DNS instead of editing `/etc/hosts` on every machine.

### Local VM (optional: Cloudflare Tunnel)

When you need **real public DNS** or off-LAN access without a public IP:

- Run `cloudflared` on the VM
- Route `ids-vm…` / `web-vm…` / etc. to nginx via the tunnel (CNAMEs in Cloudflare)
- **Do not** create A records pointing at the private LAN IP

Tunnel edge behaviour is **not** identical to beta’s “proxy → open 443”; it is still excellent for app and OIDC testing.

### LocalCan / ngrok

Useful for a single public HTTPS URL or webhooks. Awkward as the default for four stable OIDC hostnames — treat as secondary.

## Migration from Swarm

See `docs/migration-notes.md` for detailed migration notes from the old Swarm setup.

## Non-Goals

- No GitHub Actions deploy automation (yet)
- No OpenTofu/Terraform infrastructure (yet)
- No Cloudflare Tunnel **implementation** in this repo yet (documented as optional local-vm path)
- No Loki/Grafana observability (yet)

Strategic detail also lives in Identity `docs/deployment-advice.md`.
