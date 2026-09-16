# Migration Notes: Swarm → Docker Compose

## What Changed

| Aspect | Old (Swarm) | New (Compose) |
|--------|-------------|---------------|
| Orchestration | Docker Swarm stacks | Docker Compose v2 |
| Secrets | `docker secret create` + external Swarm secrets | File-based Compose secrets |
| nginx | Custom `knowledgespike/acs-nginx-*` image | `nginx:stable-alpine` with mounted configs |
| Repo layout | Per-env stacks in one repo | One compose per env in uber deploy repo |
| Images | Mixed local + published | All published images from app repos |
| Networking | Overlay networks | Bridge networks (single host) |

## Why the Change

1. **Single VPS** — Swarm adds ceremony (secrets, configs, node labels) without multi-node benefit.
2. **Local parity** — Same Compose project shape on VPS and local VM; Swarm requires a cluster. (DNS differs: beta uses Cloudflare → public IP; local VM uses hosts or Tunnel — see README.)
3. **Simplicity** — File-based secrets and mounted configs are easier for a developer to manage than Swarm external secrets.
4. **Published nginx** — No need for a custom nginx image when configs are mounted as files.

## Migration Steps

### 1. Stop Swarm Services

```bash
# On the old Swarm host
docker stack rm acs-beta
docker stack rm identity
```

### 2. Prepare Compose Host

```bash
# Install Docker Compose v2 if not present
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
  -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
```

### 3. Clone Deploy Repo

```bash
git clone <deploy-repo> /opt/acs-deploy
cd /opt/acs-deploy
```

### 4. Set Up Secrets

The old Swarm secrets need to be extracted and placed in file format:

```bash
# Extract Swarm secrets (one-time)
docker secret ls
docker secret inspect <secret_name> --format '{{.Spec.Data}}' | base64 -d > /tmp/secret_value

# Place in compose secrets
mkdir -p private/beta
echo -n "actual_value" > private/beta/ConnectionStrings__identity
# Repeat for all secrets...
```

See `private/.secret-names` for the full list of required secrets.

### 5. Set Up TLS Certificates

```bash
mkdir -p certs/beta
# Copy origin certificates
cp /path/to/server.crt certs/beta/server.crt
cp /path/to/server.key certs/beta/server.key
chmod 600 certs/beta/server.key
```

### 6. Set Up Cloudflare DNS (beta / public VPS only)

Create A records in Cloudflare pointing to the **VPS public IP** (not a laptop VM private IP):
- `ids-beta.knowledgespike.cricket`
- `adminui-beta.knowledgespike.cricket`
- `web-beta.knowledgespike.cricket`
- `api-beta.knowledgespike.cricket`

Set proxy to **orange cloud** (proxied). For local-vm name resolution, see the main README (**hosts file** or **Cloudflare Tunnel** — never A records to `192.168.x.x`).

### 7. First Deploy

```bash
cd environments/beta
../../scripts/deploy.sh
```

### 8. Verify

```bash
# Check all services are healthy
docker compose ps

# Test endpoints
curl -k https://localhost/healthz
curl -k https://ids-beta.knowledgespike.cricket/.well-known/openid-configuration
```

## What to Keep from Swarm

- **Secret names** — The compose secrets use the same names as Swarm secrets where possible, so app configuration doesn't change.
- **URL contracts** — Public hostnames (`ids-beta.knowledgespike.cricket`, etc.) remain the same.
- **Database data** — MariaDB volume is preserved; no data migration needed if running on the same host.

## What to Retire

- `knowledgespike/acs-nginx-*` Docker Hub images — no longer needed.
- Swarm `docker secret create` commands — replaced by file-based secrets.
- `stack-beta.yaml`, `stack-dev.yaml`, `stack-staging.yaml` — replaced by compose files.
- Node labels (`node.labels.identity.db == true`) — not needed on a single node.

## Known Differences

1. **No Swarm rollback** — Compose doesn't have built-in rollback. Use pinned image tags and manual rollback.
2. **No Swarm configs** — nginx config is a mounted file, not a Swarm config object.
3. **Healthcheck timing** — Compose healthchecks may differ slightly from Swarm; adjust `start_period` if needed.

## Rollback Plan

If something goes wrong:

```bash
# Stop compose
cd environments/beta
docker compose down

# Revert to previous image tags in .env
# Edit .env to point to previous sha tags
# Redeploy
../../scripts/deploy.sh
```

## Future: OpenTofu/Terraform

When you're ready to automate server bootstrap:

1. Install Docker and Compose
2. Configure UFW firewall (ports 80, 443 only)
3. Create deploy user with SSH keys
4. Set up Cloudflare DNS records for the **public VPS** (beta)
5. Clone and configure this deploy repo

This is **not** part of v1 — manual setup is fine for now.
