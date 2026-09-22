# Beta Environment Deployment Guide (Step-by-Step)

This guide walks you step-by-step through deploying the full application stack to the remote **Beta Virtual Private Server (VPS)**.

You will run the **exact same 8-container Docker Compose stack** used in the local VM environment, but deployed on a public Linux host behind **Cloudflare** for DNS, CDN, and public TLS termination.

---

## Architecture Overview

When deployed, your Beta VPS runs 8 interconnected containers inside a single Docker network (`beta_acs-net`):

```
Laptop / Client Browser
      │
      │  https://*.knowledgespike.cricket (Cloudflare Proxied DNS / Orange Cloud)
      ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│ Cloudflare Edge CDN & Reverse Proxy                                              │
│ SSL/TLS Mode: Full (strict)                                                      │
└──────────────────────────────────────┬───────────────────────────────────────────┘
                                       │
                                       │ HTTPS (Port 443 with Cloudflare Origin CA)
                                       ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│ Beta Linux VPS                                                                   │
│                                                                                  │
│  ┌────────────────────────────────────────────────────────────────────────────┐  │
│  │ nginx (Edge Reverse Proxy, ports 80 & 443)                                 │  │
│  └──────┬────────────┬─────────────┬────────────┬─────────────┬────────────┬──┘  │
│         │            │             │            │             │            │     │
│         ▼            ▼             ▼            ▼             ▼            ▼     │
│     ┌───────┐  ┌───────────┐  ┌─────────┐  ┌─────────┐   ┌─────────┐  ┌─────────┐│
│     │  ids  │  │  adminui  │  │ acs-web │  │ acs-api │   │ bbb-web │  │ bbb-api ││
│     └───┬───┘  └─────┬─────┘  └────┬────┘  └────┬────┘   └────┬────┘  └────┬────┘│
│         │            │             │            │              │            │    │
│         │            │             │ OIDC Auth  │              │ OIDC Auth  │    │
│         │            │             └───────────►│              └───────────►│    │
│         │            │                          │                           │    │
│         ▼            ▼                          ▼                           ▼    │
│     ┌────────────────────────────────────────────────────────────────────────┐   │
│     │ MariaDB (Port 3306, internal only)                                     │   │
│     │ Databases: identity, cricketarchive, acs_ball_by_ball, cricket         │   │
│     └────────────────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### The Four Databases

The MariaDB container hosts all application databases on one instance:

1. **`identity`** — Used by IdentityServer (`ids`) and AdminUI for user accounts, client definitions, operational grants, and Data Protection keys.
2. **`cricketarchive`** — Used by the Cricket Archive API (`acs-api`).
3. **`acs_ball_by_ball`** — Used by the Ball-by-Ball API (`bbb-api`).
4. **`cricket`** — Used for cricket statistics and upcoming applications.

**Automatic Initialization:**  
When MariaDB starts up for the first time with a fresh volume, it automatically runs initialization scripts mounted in `/docker-entrypoint-initdb.d/`:
1. `mariadb/init/01-init-databases.sh`: Creates all four databases (`identity`, `cricketarchive`, `acs_ball_by_ball`, `cricket`) and configures their application users and permissions.
2. `mariadb/init/02-init-identity-data.sh`: Automatically applies the clean identity baseline data (`mariadb/init/identity-baseline.sql.template`), substituting Beta hostnames and hashed client secrets for AdminUI, ACS Web, and BBB Web.

> **Upgrading an Existing Beta MariaDB Volume:**  
> MariaDB only executes `/docker-entrypoint-initdb.d/` scripts on fresh, empty data volumes. If your Beta MariaDB volume was initialized prior to `acs_ball_by_ball` being added, create the database and grant user privileges manually without losing existing data:
> ```bash
> docker compose -f environments/beta/compose.yaml exec -T mariadb sh -c \
>   'mariadb -u root -p"$(cat /run/secrets/mariadb_root_password)" -e "
>     CREATE DATABASE IF NOT EXISTS \`acs_ball_by_ball\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
>     GRANT ALL PRIVILEGES ON \`acs_ball_by_ball\`.* TO \"$(cat /run/secrets/jdbc.username)\"@\"%\";
>     FLUSH PRIVILEGES;
>   "'
> ```

---

## Prerequisites

Before deploying to Beta, ensure you have:

- A Linux VPS (Ubuntu 22.04 or 24.04 LTS recommended) with at least 4 GB RAM.
- A public IPv4 address assigned to the VPS (e.g. `152.53.60.160`).
- Administrative SSH access to the VPS (`ssh <user>@<VPS_IP>`).
- Access to the **Cloudflare Dashboard** managing the `knowledgespike.cricket` zone.
- `openssl` and `git` installed on both your laptop and the VPS.

---

## Step 1: DNS & Cloudflare Configuration

Traffic to the Beta environment is proxied through Cloudflare to provide DDoS protection, CDN caching, and seamless TLS certificates.

### Step 1.1: Configure Cloudflare DNS A Records

In the Cloudflare Dashboard for `knowledgespike.cricket`, go to **DNS** > **Records** and create `A` records pointing to your Beta VPS public IP address (replace `152.53.60.160` with your actual VPS IP):

| Type | Name | Content (IPv4) | Proxy Status | Description |
|---|---|---|---|---|
| `A` | `ids-beta` | `152.53.60.160` | Proxied (Orange Cloud) | IdentityServer |
| `A` | `adminui-beta` | `152.53.60.160` | Proxied (Orange Cloud) | Duende AdminUI |
| `A` | `stats-beta` | `152.53.60.160` | Proxied (Orange Cloud) | ACS Web Application |
| `A` | `web-beta` | `152.53.60.160` | Proxied (Orange Cloud) | Legacy / alias for ACS Web |
| `A` | `stats-api-beta`| `152.53.60.160` | Proxied (Orange Cloud) | ACS Statistics API |
| `A` | `api-beta` | `152.53.60.160` | Proxied (Orange Cloud) | Legacy / alias for ACS API |
| `A` | `bbb-beta` | `152.53.60.160` | Proxied (Orange Cloud) | Ball-by-Ball Web Application |
| `A` | `bbb-api-beta` | `152.53.60.160` | Proxied (Orange Cloud) | Ball-by-Ball API |

> **Important:** Always leave the **Proxy status** set to **Proxied** (orange cloud). This ensures Cloudflare terminates client TLS and forwards requests to the origin VPS.

### Step 1.2: Set SSL/TLS Encryption Mode to Full (strict)

1. In Cloudflare, navigate to **SSL/TLS** > **Overview**.
2. Select **Full (strict)** encryption mode.  
   *(This ensures end-to-end encryption between Cloudflare edge servers and your VPS origin Nginx proxy using a validated certificate).*

### Step 1.3: Generate a Cloudflare Origin CA Certificate

1. In Cloudflare, navigate to **SSL/TLS** > **Origin Server**.
2. Click **Create Certificate**.
3. Keep the default settings:
   - **Key type:** RSA (2048)
   - **Hostnames:** `*.knowledgespike.cricket`, `knowledgespike.cricket`
   - **Certificate Validity:** 15 years (recommended)
4. Click **Create**.
5. Keep this browser tab open. You will paste the certificate into `certs/beta/server.crt` and the private key into `certs/beta/server.key` during Step 6.

---

## Step 2: Install Docker and Docker Compose on the VPS

SSH into your Beta VPS:
```bash
ssh <user>@<VPS_IP>
```

1. Update packages and install prerequisites:
   ```bash
   sudo apt-get update
   sudo apt-get install -y ca-certificates curl gnupg
   ```

2. Add Docker's official GPG key:
   ```bash
   sudo install -m 0755 -d /etc/apt/keyrings
   sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
   sudo chmod a+r /etc/apt/keyrings/docker.asc
   ```

3. Add the Docker repository to Apt sources:
   ```bash
   echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
     $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
     sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
   ```

4. Install Docker Engine and the Compose plugin:
   ```bash
   sudo apt-get update
   sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
   ```

5. Add your user to the `docker` group so you can run Docker commands without `sudo`:
   ```bash
   sudo usermod -aG docker "$USER"
   newgrp docker
   ```

6. Verify the installation:
   ```bash
   docker --version
   docker compose version
   ```

7. Configure the UFW firewall:
   ```bash
   sudo ufw allow OpenSSH
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw enable
   ```
   *(Optional hardening: You can restrict inbound traffic on ports 80 and 443 exclusively to [Cloudflare IP ranges](https://www.cloudflare.com/ips/) so direct VPS IP bypass is blocked).*

---

## Step 3: Copy or Clone `acs-deploy` to the VPS

Place the `acs-deploy` project into your home directory on the VPS (`~/acs-deploy`).

**Option A — Clone from GitHub:**
```bash
git clone https://github.com/kevinrjones/KSCricketDeploy.git ~/acs-deploy
cd ~/acs-deploy
```

**Option B — Copy from your laptop via rsync:**
Run this on your **laptop**:
```bash
rsync -avz --exclude '.git' --exclude 'node_modules' \
  /Users/kevinjones/Dropbox/projects/cricket/acs-deploy/ \
  <user>@<VPS_IP>:~/acs-deploy/
```

Then SSH into the VPS:
```bash
ssh <user>@<VPS_IP>
cd ~/acs-deploy
```

---

## Step 4: Configure the Environment File

The `.env` file defines image tags, hostnames, and database settings for the Beta environment.

1. Create or edit `environments/beta/.env`:
   ```bash
   cp .env.example environments/beta/.env
   nano environments/beta/.env
   ```

2. Configure the Beta settings:
   ```bash
   # Docker Images
   IDS_IMAGE=knowledgespike/acs-cricketarchive-ids:latest
   ADMINUI_IMAGE=knowledgespike/acs-cricketarchive-adminui:latest
   ACS_WEB_IMAGE=knowledgespike/acs-cricketarchive-web:latest
   ACS_API_IMAGE=knowledgespike/acs-cricketarchive-api:latest
   BBB_WEB_IMAGE=knowledgespike/bbb-web:latest
   BBB_API_IMAGE=knowledgespike/bbb-api:latest
   MARIADB_IMAGE=mariadb:11
   NGINX_IMAGE=nginx:stable-alpine

   # Hostnames for Beta routing
   IDS_HOSTNAME=ids-beta.knowledgespike.cricket
   ADMINUI_HOSTNAME=adminui-beta.knowledgespike.cricket
   ACS_WEB_HOSTNAME=stats-beta.knowledgespike.cricket
   ACS_API_HOSTNAME=stats-api-beta.knowledgespike.cricket
   BBB_WEB_HOSTNAME=bbb-beta.knowledgespike.cricket
   BBB_API_HOSTNAME=bbb-api-beta.knowledgespike.cricket

   # MariaDB App User
   MARIADB_DATABASE=identity
   MARIADB_USER=identity

   # OIDC Credentials & Environment
   STATS_OIDC_CLIENT_ID=acsstats
   STATS_OIDC_CLIENT_SECRET=change-me-to-the-identity-client-secret
   BBB_OIDC_CLIENT_ID=ballbyball
   BBB_OIDC_CLIENT_SECRET=change-me-to-the-identity-client-secret
   KTOR_ENVIRONMENT=beta

   TZ=UTC
   ```

3. Set `STATS_OIDC_CLIENT_SECRET` and `BBB_OIDC_CLIENT_SECRET` to the client secrets configured in IdentityServer. Save and exit (`Ctrl+O`, `Enter`, `Ctrl+X`).

---

## Step 5: Generate and Configure Secret Files

Sensitive data (passwords, connection strings, license keys) are stored as individual files under `private/beta/` and mounted into `/run/secrets/` inside containers.

### Step 5.1: Run the automated secret generator

Run the included helper script to generate random secure passwords, matching database connection strings, and the Data Protection certificate:

```bash
chmod +x scripts/generate-beta-secrets.sh
./scripts/generate-beta-secrets.sh
```

This script automatically creates:
- `mariadb_root_password` — Random MariaDB root password.
- `mariadb_password` — Random password for the `identity` user.
- `ConnectionStrings__identity` — Connection string for IdentityServer pointing to MariaDB.
- `IdentityConnectionString` & `IdentityServerConnectionString` — Matching connection strings for AdminUI.
- `jdbc.username` (`cricketarchive`) & `jdbc.password` — Credentials for the ACS and BBB APIs.
- `DataProtection__Certificate__Password` & `certs/beta/ids-mysql-dp.pfx` — ASP.NET Data Protection encryption key.
- `AdminUIClientSecret` & `UsernamePolicy__Secret` — AdminUI operational credentials.

### Step 5.2: Set vendor license and credentials

`scripts/generate-beta-secrets.sh` pre-configures the active Duende AdminUI development license key. If you have your own commercial key or need to set Google OAuth credentials:

```bash
# 1. Duende AdminUI License Key (if updating or replacing)
printf '%s' 'PASTE_YOUR_ADMINUI_LICENSE_KEY_HERE' > private/beta/LicenseKey

# 2. Google OAuth credentials (required by IdentityServer on boot)
printf '%s' 'YOUR_GOOGLE_CLIENT_ID' > private/beta/Authentication__Google__ClientId
printf '%s' 'YOUR_GOOGLE_CLIENT_SECRET' > private/beta/Authentication__Google__ClientSecret

# 3. Set file permissions so container users can read secrets
chmod 755 private/beta certs/beta
chmod 644 private/beta/*
chmod 644 certs/beta/ids-mysql-dp.pfx
```

---

## Step 6: Configure TLS Certificates (Cloudflare Origin CA)

Because Beta runs behind Cloudflare with **Full (strict)** SSL/TLS mode, Nginx requires a valid Origin Certificate signed by Cloudflare.

1. Ensure the certificate directory exists:
   ```bash
   mkdir -p certs/beta
   chmod 755 certs/beta
   ```

2. Create `certs/beta/server.crt` and paste the **Origin Certificate** generated in Step 1.3:
   ```bash
   nano certs/beta/server.crt
   ```
   Paste the complete certificate including `-----BEGIN CERTIFICATE-----` and `-----END CERTIFICATE-----`. Save and exit.

3. Create `certs/beta/server.key` and paste the **Private Key** generated in Step 1.3:
   ```bash
   nano certs/beta/server.key
   ```
   Paste the complete private key including `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----`. Save and exit.

4. Secure the certificate file permissions:
   ```bash
   chmod 644 certs/beta/server.crt
   chmod 600 certs/beta/server.key
   ```

> **Note on JVM Truststores:**  
> Unlike the local VM environment (which requires mounting a custom `cacerts` bundle for self-signed certificates), Beta containers connect to public HTTPS endpoints that are trusted by default in the official OpenJDK JVM truststore. No custom `cacerts` mount is required.

---

## Step 7: Deploy the Application Stack

On your **Beta VPS**, start the stack:

1. Run the deployment script:
   ```bash
   cd ~/acs-deploy
   chmod +x scripts/deploy.sh
   ./scripts/deploy.sh beta
   ```

2. What `deploy.sh` does:
   - Pulls the latest container images from Docker Hub.
   - Starts MariaDB, mounts `mariadb/init/01-init-databases.sh`, and initializes all four databases (`identity`, `cricketarchive`, `acs_ball_by_ball`, `cricket`).
   - Seeds IdentityServer baseline data with Beta hostnames via `mariadb/init/02-init-identity-data.sh`.
   - Starts IdentityServer, AdminUI, ACS Web, ACS API, BBB Web, and BBB API.
   - Starts Nginx on ports 80 and 443 with your Cloudflare Origin Certificate.
   - Monitors container health checks until all services report healthy.

3. Verify running containers:
   ```bash
   cd ~/acs-deploy/environments/beta
   docker compose --env-file .env ps
   ```
   All 8 services (`mariadb`, `ids`, `adminui`, `acs-web`, `acs-api`, `bbb-web`, `bbb-api`, `nginx`) should show `Up` or `Up (healthy)`.

---

## Step 8: Verify Everything Works

### Step 8.1: Test health endpoints via curl

From your **laptop**, test each service over public HTTPS:

```bash
# IdentityServer health endpoint
curl -fsS https://ids-beta.knowledgespike.cricket/health/ready && echo " -> IdS OK"

# AdminUI root page
curl -fsS -o /dev/null https://adminui-beta.knowledgespike.cricket/ && echo "AdminUI OK"

# ACS API health endpoint (Ktor heartbeat route)
curl -fsS https://stats-api-beta.knowledgespike.cricket/heartbeat/alive && echo " -> ACS API OK"

# ACS Web home page
curl -fsS -o /dev/null https://stats-beta.knowledgespike.cricket/ && echo "ACS Web OK"

# BBB API health endpoint (Ktor heartbeat route)
curl -fsS https://bbb-api-beta.knowledgespike.cricket/api/heartbeat/alive && echo " -> BBB API OK"

# BBB Web home page
curl -fsS -o /dev/null https://bbb-beta.knowledgespike.cricket/ && echo "BBB Web OK"
```

### Step 8.2: Test in your browser

1. Open **`https://ids-beta.knowledgespike.cricket`** in your browser:
   - You should see the IdentityServer landing page with a secure Cloudflare SSL lock.
2. Open **`https://adminui-beta.knowledgespike.cricket`**:
   - You should see the AdminUI login and dashboard.
3. Open **`https://stats-beta.knowledgespike.cricket`**:
   - Click login. You should be redirected to `ids-beta.knowledgespike.cricket` for authentication, and return back to `stats-beta.knowledgespike.cricket/signin-oidc`.
4. Open **`https://bbb-beta.knowledgespike.cricket`**:
   - Click login. You should be redirected to `ids-beta.knowledgespike.cricket` for authentication, and return back to `bbb-beta.knowledgespike.cricket/signin-oidc`.

---

## Step 9: Import Application Data into MariaDB

The application stack uses two primary data stores for cricket information:
1. **`cricketarchive`** — Contains all matches, players, teams, grounds, and statistics consumed by the ACS API (`acs-api`).
2. **`acs_ball_by_ball`** — Dimensional warehouse containing delivery and match details consumed by the Ball-by-Ball API (`bbb-api`).

---

### Step 9.1: Import CricketArchive Data (`cricketarchive`)

#### Option A: Direct Command Line (Run on the VPS)

From your **VPS terminal**, stream the SQL dump into the running MariaDB container:

```bash
cd ~/acs-deploy

# If using uncompressed SQL:
docker compose -f environments/beta/compose.yaml exec -T mariadb sh -c \
  'mariadb -u root -p"$(cat /run/secrets/mariadb_root_password)" --max-allowed-packet=1G cricketarchive' \
  < /path/to/cricketarchive-upload.sql

# Or if using a gzipped dump:
gunzip -c /path/to/cricketarchive-upload.sql.gz | docker compose -f environments/beta/compose.yaml exec -T mariadb sh -c \
  'mariadb -u root -p"$(cat /run/secrets/mariadb_root_password)" --max-allowed-packet=1G cricketarchive'
```

#### Option B: Stream Directly from Your Laptop over SSH

You can stream the SQL dump from your laptop directly into the remote MariaDB container without uploading large intermediate files to the VPS disk:

```bash
# Using the helper script from your laptop:
./scripts/import-cricket-data.sh ~/Dropbox/dumps/mysql/cricketarchive-upload.sql.gz beta --remote <user>@<VPS_IP>

# Or via direct SSH pipe:
gunzip -c ~/Dropbox/dumps/mysql/cricketarchive-upload.sql.gz | ssh <user>@<VPS_IP> \
  'docker compose -f ~/acs-deploy/environments/beta/compose.yaml exec -T mariadb sh -c \
   "mariadb -u root -p\$(cat /run/secrets/mariadb_root_password) --max-allowed-packet=1G cricketarchive"'
```

#### Verify CricketArchive Import

Verify the imported tables and record counts from the VPS:

```bash
cd ~/acs-deploy/environments/beta
docker compose exec mariadb sh -c '
  mariadb -u root -p"$(cat /run/secrets/mariadb_root_password)" -e "
    SELECT count(*) AS total_tables FROM information_schema.tables WHERE table_schema=\"cricketarchive\";
    SELECT \"Matches\" AS tbl, count(*) AS count FROM cricketarchive.Matches UNION ALL
    SELECT \"Players\", count(*) FROM cricketarchive.Players UNION ALL
    SELECT \"Teams\", count(*) FROM cricketarchive.Teams;
  "
'
```

And test the ACS API health route:
```bash
curl -fsS https://stats-api-beta.knowledgespike.cricket/heartbeat/alive && echo " -> API OK"
```

---

### Step 9.2: Import Ball-by-Ball Data (`acs_ball_by_ball`)

The Ball-by-Ball database dump (`ball-by-ball-upload.sql` or `ball-by-ball-upload.sql.gz`) populates the dimensional warehouse tables (`dim_match`, `dim_person`, `dim_team`, `fact_delivery`) required by `bbb-api`.

#### Option A: Direct Command Line (Run on the VPS)

From your **VPS terminal**, stream the SQL dump into the running MariaDB container:

```bash
cd ~/acs-deploy

# If using uncompressed SQL:
docker compose -f environments/beta/compose.yaml exec -T mariadb sh -c \
  'mariadb -u root -p"$(cat /run/secrets/mariadb_root_password)" --max-allowed-packet=1G acs_ball_by_ball' \
  < /path/to/ball-by-ball-upload.sql

# Or if using a gzipped dump:
gunzip -c /path/to/ball-by-ball-upload.sql.gz | docker compose -f environments/beta/compose.yaml exec -T mariadb sh -c \
  'mariadb -u root -p"$(cat /run/secrets/mariadb_root_password)" --max-allowed-packet=1G acs_ball_by_ball'
```

#### Option B: Stream Directly from Your Laptop over SSH

Use `scripts/import-ball-by-ball-data.sh` to stream from your laptop over SSH:

```bash
# Using the helper script:
./scripts/import-ball-by-ball-data.sh ~/Dropbox/dumps/mysql/ball-by-ball-upload.sql.gz beta --remote <user>@<VPS_IP>

# Or via direct SSH pipe:
gunzip -c ~/Dropbox/dumps/mysql/ball-by-ball-upload.sql.gz | ssh <user>@<VPS_IP> \
  'docker compose -f ~/acs-deploy/environments/beta/compose.yaml exec -T mariadb sh -c \
   "mariadb -u root -p\$(cat /run/secrets/mariadb_root_password) --max-allowed-packet=1G acs_ball_by_ball"'
```

#### Verify Ball-by-Ball Import

Verify the imported dimensional warehouse tables and record counts from the VPS:

```bash
cd ~/acs-deploy/environments/beta
docker compose exec mariadb sh -c '
  mariadb -u root -p"$(cat /run/secrets/mariadb_root_password)" -e "
    SELECT count(*) AS total_tables FROM information_schema.tables WHERE table_schema=\"acs_ball_by_ball\";
    SELECT \"dim_match\" AS tbl, count(*) AS count FROM acs_ball_by_ball.dim_match UNION ALL
    SELECT \"dim_person\", count(*) FROM acs_ball_by_ball.dim_person UNION ALL
    SELECT \"dim_team\", count(*) FROM acs_ball_by_ball.dim_team UNION ALL
    SELECT \"fact_delivery\", count(*) FROM acs_ball_by_ball.fact_delivery;
  "
'
```

And test the BBB API heartbeat route:
```bash
curl -fsS https://bbb-api-beta.knowledgespike.cricket/api/heartbeat/alive && echo " -> BBB API OK"
```

---

### Step 9.3: Seed or Re-seed IdentityServer Baseline

If you ever need to reset or refresh the IdentityServer database on Beta with clean configuration and users:

```bash
cd ~/acs-deploy
chmod +x scripts/import-identity-db.sh
./scripts/import-identity-db.sh beta
```

---

## Step 10: Common Operations & Maintenance

### View live logs

On the VPS:
```bash
cd ~/acs-deploy/environments/beta

# View logs for a specific service
docker compose --env-file .env logs -f ids
docker compose --env-file .env logs -f adminui
docker compose --env-file .env logs -f acs-api
docker compose --env-file .env logs -f acs-web
docker compose --env-file .env logs -f bbb-api
docker compose --env-file .env logs -f bbb-web
docker compose --env-file .env logs -f nginx
docker compose --env-file .env logs -f mariadb
```

### Restart a single service

```bash
cd ~/acs-deploy/environments/beta
docker compose --env-file .env restart acs-web
```

### Stop and start the stack

```bash
cd ~/acs-deploy/environments/beta

# Stop all containers
docker compose --env-file .env down

# Start everything back up
docker compose --env-file .env up -d
```

### Back up the MariaDB databases

A backup script is included that dumps all databases (`identity`, `cricketarchive`, `acs_ball_by_ball`, `cricket`) to a timestamped compressed archive:

```bash
cd ~/acs-deploy
chmod +x scripts/backup.sh
./scripts/backup.sh backups/beta beta
```
Backups are saved to `backups/beta/`.

### Updating Container Images

When new images are pushed to Docker Hub:
```bash
cd ~/acs-deploy
./scripts/deploy.sh beta
```
The deploy script pulls newer image layers and recreates updated containers with zero downtime.

---

## Troubleshooting

| Symptom | Cause | Solution |
|---|---|---|
| **Cloudflare Error 521: Web Server Is Down** | Nginx container is not running, or VPS firewall is blocking port 443 | On VPS, check `docker compose ps` in `environments/beta`. Ensure UFW allows traffic: `sudo ufw allow 80/tcp && sudo ufw allow 443/tcp`. |
| **Cloudflare Error 522: Connection Timed Out** | Cloudflare cannot establish a TCP handshake with your VPS IP | Verify that the DNS A record in Cloudflare matches your VPS public IP. Verify VPS routing and gateway. |
| **Cloudflare Error 525: SSL Handshake Failed** | SSL/TLS mode is Full (strict) but `server.crt` / `server.key` are missing, invalid, or expired | Check `certs/beta/server.crt` and `server.key`. Ensure they contain a valid Cloudflare Origin Certificate for `*.knowledgespike.cricket`. Check Nginx logs: `docker compose logs nginx`. |
| **Cloudflare Error 520 / 502 Bad Gateway** | Upstream application container crashed or is not responding | Check container logs (e.g. `docker compose logs -f acs-web` or `bbb-api`). |
| **IdentityServer fails on boot** | Missing Google OAuth credentials | Ensure `Authentication__Google__ClientId` and `Authentication__Google__ClientSecret` have values in `private/beta/`. |
| **AdminUI shows license error** | Missing or expired Duende license | Verify `private/beta/LicenseKey` file contents. |
| **BBB API: Socket fail to connect to localhost (`Connection refused`)** | Container missing `DB_JDBC_URL` environment variable | Ensure `DB_JDBC_URL: jdbc:mariadb://mariadb:3306/acs_ball_by_ball` is present in `environments/beta/compose.yaml` under `bbb-api`. |
| **BBB API: 502 Bad Gateway / Connection refused from upstream** | `API_HOST: 0.0.0.0` missing; Ktor binds strictly to `localhost` inside container | Ensure `API_HOST: 0.0.0.0` is present in `compose.yaml` under `bbb-api` and restart: `docker compose up -d --force-recreate bbb-api`. |
| **BBB Web / IdS: unauthorized_client on login** | `ClientRedirectUris` in IdentityServer lacks `https://bbb-beta.knowledgespike.cricket/signin-oidc` | Re-seed identity database: `./scripts/import-identity-db.sh beta`, or run SQL: `INSERT INTO identity.ClientRedirectUris (ClientId, RedirectUri) SELECT Id, 'https://bbb-beta.knowledgespike.cricket/signin-oidc' FROM identity.Clients WHERE ClientId = 'ballbyball';`. |
| **OIDC Login: Redirect URI mismatch** | Client redirect URI in Identity does not match `https://stats-beta...` | Log into AdminUI and verify that the `acsstats` client has `https://stats-beta.knowledgespike.cricket/signin-oidc` registered as an allowed redirect URI. |
