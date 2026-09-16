# ACS Deploy — Uber Deployment Repository

> **Purpose:** Single Docker Compose project to deploy Identity Server, AdminUI, and ACS services on a shared VPS or local VM behind a single edge nginx.

## Quick Start

**Laptop local VM (hosts file + private CA):** follow the full walkthrough → **[docs/local-vm-deploy.md](docs/local-vm-deploy.md)**.

**Beta / VPS (short form):**

```bash
# 1. Clone this repo onto the VPS
git clone <this-repo> acs-deploy && cd acs-deploy

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
    → ids / adminui / acs-web / acs-api / mariadb
```

**Local VM (laptop VM — private LAN IP only):**

```
Your laptop hosts file (or optional Cloudflare Tunnel)
  → nginx edge (port 443 on VM)
    → same services as beta
```

All services share one Docker network. nginx routes by `Host` header. Only ports 80 and 443 are exposed on the host.

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
├── certs/                  # Origin TLS certificates (gitignored)
├── scripts/
│   ├── deploy.sh                    # Deploy script (pull + up)
│   ├── backup.sh                    # MariaDB backup script
│   └── generate-local-vm-certs.sh   # Private CA + nginx cert for *-vm hostnames
├── private/                # Per-env secret files (placeholders committed; real values gitignored patterns)
│   ├── beta/
│   └── local-vm/
└── docs/
    ├── local-vm-deploy.md  # Step-by-step laptop VM: hosts, certs, deploy
    └── migration-notes.md  # Notes on migrating from Swarm
```

## Environments

| Environment | Compose Project | Hostnames | How names reach the host |
|-------------|-----------------|-----------|--------------------------|
| **Beta** | `environments/beta/compose.yaml` | `*-beta.knowledgespike.cricket` | Cloudflare orange-cloud A/AAAA → **VPS public IP** |
| **Local VM** | `environments/local-vm/compose.yaml` | `*-vm.knowledgespike.cricket` | **Hosts/split-DNS** → VM LAN IP (default), or **Cloudflare Tunnel** — **not** CF A → private IP |

Each environment has its own `.env` with hostnames, image tags, and secret paths. Compose shape stays the same; DNS/TLS front door differs.

## Image Registry

All images are published to Docker Hub by their respective app repositories:

| Service | Image | Source Repo |
|---------|-------|-------------|
| IdentityServer | `knowledgespike/ids` | Identity repo |
| AdminUI | `knowledgespike/adminui` | Identity repo |
| ACS Web | `knowledgespike/acs-cricketarchive-web` | KSCricket repo |
| ACS API | `knowledgespike/acs-cricketarchive-api` | KSCricket repo |
| MariaDB | `mariadb:11` | Official |
| nginx | `nginx:stable-alpine` | Official |

### Image Tagging

Images are tagged with:
- `:latest` — most recent build
- `:v*.*.*` — semantic version tags
- `:sha-<12-char-commit>` — commit-specific tags

**Pin to `sha-` tags in production** for reproducible deployments.

## Secrets

Secrets are managed via file-based secrets (not Swarm secrets). The `private/` directory contains:

1. `.secret-names` — Template listing all required secrets (committed)
2. `.secrets` — Actual secret values (gitignored)

### Required Secrets

| Secret Name | Description | Used By |
|-------------|-------------|---------|
| `ConnectionStrings__identity` | MariaDB connection string for Identity | ids, adminui |
| `ConnectionStrings__configuration` | MariaDB connection string for IdS config | ids |
| `ConnectionStrings__persistedgrants` | MariaDB connection string for IdS grants | ids |
| `DataProtection__Keys__ConnectionString` | MariaDB connection string for DP keys | ids |
| `DataProtection__Keys__ProtectKeysWithCertificate` | Certificate thumbprint for DP keys | ids |
| `Authentication__Google__ClientId` | Google OAuth client ID | ids |
| `Authentication__Google__ClientSecret` | Google OAuth client secret | ids |
| `AdminUI__LicenseKey` | AdminUI license key | adminui |
| `ACS__ApiSecret` | ACS API secret for internal auth | acs-api |

### How to Set Secrets

```bash
# 1. Copy the template
cp private/.secret-names private/.secrets

# 2. Edit with actual values
$EDITOR private/.secrets

# 3. Ensure permissions are restrictive
chmod 600 private/.secrets
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

- Run `./scripts/generate-local-vm-certs.sh` (or manual OpenSSL in the local-vm guide) so SANs cover the four `*-vm` hostnames
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

## DNS and local VM

### Why local VM ≠ Cloudflare A record

A typical laptop VM has only a **private** IP. Cloudflare (orange-cloud **or** grey-cloud) cannot usefully target that address as an origin: the public internet — including Cloudflare’s network — cannot route to `192.168.x.x` / `10.x.x.x`.

| Environment | Public IP? | Supported front door |
|-------------|------------|----------------------|
| **Beta (Netcup)** | Yes | Cloudflare orange-cloud → VPS IP → origin nginx |
| **Local VM (LAN)** | No | Hosts/split-DNS → VM IP + local TLS, **or** Cloudflare Tunnel |

Compose, image pins, secrets, and Host-based nginx stay the same. Only **name resolution and TLS front door** change.

### Beta (Cloudflare)

Create A/AAAA records to the **VPS public IP** only:

| Hostname | Type | Proxy |
|----------|------|-------|
| `ids-beta.knowledgespike.cricket` | A | Orange (proxied) |
| `adminui-beta.knowledgespike.cricket` | A | Orange (proxied) |
| `web-beta.knowledgespike.cricket` | A | Orange (proxied) |
| `api-beta.knowledgespike.cricket` | A | Orange (proxied) |

### Local VM (default: hosts file)

**Full steps (VM setup, Docker, secrets, OpenSSL/CA, hosts, trust store, verify):** see **[docs/local-vm-deploy.md](docs/local-vm-deploy.md)**.

Short version:

1. Generate certs: `./scripts/generate-local-vm-certs.sh` → `certs/local-vm/server.crt|key` + `dev-ca.crt`.
2. Deploy `environments/local-vm` on the VM (`./scripts/deploy.sh local-vm`).
3. On the **laptop**, map names to the VM LAN IP:

```text
192.168.x.x  ids-vm.knowledgespike.cricket adminui-vm.knowledgespike.cricket web-vm.knowledgespike.cricket api-vm.knowledgespike.cricket
```

4. Trust `certs/local-vm/dev-ca.crt` on those clients.
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
