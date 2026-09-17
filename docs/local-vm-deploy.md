# Local VM Deployment Guide (Step-by-Step)

This guide walks you step-by-step through deploying the full application stack to a Linux Virtual Machine running on your laptop.

You will run the **exact same Docker Compose stack** used in production/beta, but reached locally through your laptop's `hosts` file and secured with a local private Certificate Authority (CA).

---

## Architecture Overview

When deployed, your VM will run 6 interconnected containers inside a single Docker network:

```
Laptop Browser
      │
      │  https://*.knowledgespike.cricket (via /etc/hosts -> VM IP)
      ▼
┌────────────────────────────────────────────────────────┐
│ Linux VM                                               │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ nginx (Edge Reverse Proxy, ports 80 & 443)       │  │
│  └──────┬────────────┬─────────────┬────────────┬───┘  │
│         │            │             │            │      │
│         ▼            ▼             ▼            ▼      │
│     ┌───────┐  ┌───────────┐  ┌─────────┐  ┌─────────┐ │
│     │  ids  │  │  adminui  │  │ acs-web │  │ acs-api │ │
│     └───┬───┘  └─────┬─────┘  └────┬────┘  └────┬────┘ │
│         │            │             │            │      │
│         │            │             │ OIDC Auth  │      │
│         │            │             └───────────►│      │
│         │            │                          │      │
│         ▼            ▼                          ▼      │
│     ┌────────────────────────────────────────────────┐ │
│     │ MariaDB (Port 3306, internal only)             │ │
│     │ Databases: identity, cricketarchive, cricket   │ │
│     └────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────┘
```

### The Three Databases

The MariaDB container hosts all application databases on one instance:

1. **`identity`** — Used by IdentityServer (`ids`) and AdminUI for user accounts, configuration, operational grants, and Data Protection keys.
2. **`cricketarchive`** — Used by the Cricket Archive API (`acs-api`).
3. **`cricket`** — Used for cricket statistics and upcoming applications.

**Automatic Initialization:**  
In the old Docker Swarm setup, SQL scripts were mounted into `/docker-entrypoint-initdb.d`. We use that exact same automatic pattern here:
1. `mariadb/init/01-init-databases.sh`: Creates all three databases (`identity`, `cricketarchive`, `cricket`) and configures their application users and permissions.
2. `mariadb/init/02-init-identity-data.sh`: Automatically applies the clean identity baseline data (`mariadb/init/identity-baseline.sql.template`), substituting VM hostnames and hashed client secrets for AdminUI and ACS Web.

When MariaDB starts up for the first time with a fresh volume, it automatically runs these scripts. You don't need to manually run any SQL to get started! If you ever need to re-seed an existing container, you can also run `./scripts/import-identity-db.sh local-vm`.

---

## Prerequisites

Before you start, make sure you have:

- A virtualization app on your laptop (UTM, VirtualBox, VMware Fusion, or Parallels).
- A Linux VM installed (Ubuntu 22.04 or 24.04 LTS recommended) with at least 4 GB RAM.
- Administrative (sudo) access on both your laptop and the VM.
- `openssl` installed on your laptop (standard on macOS and Linux).

---

## Step 1: Set Up VM Networking & Note the VM IP

To reach your VM by domain name from your laptop browser, the VM must have a network address that your laptop can communicate with.

1. In your hypervisor settings, configure the VM network adapter:
   - **Bridged Networking** (recommended): Your VM gets its own IP address on your home/office Wi-Fi or LAN (e.g. `192.168.1.50`).
   - Alternatively, **Host-Only / Shared Networking**: Gives the VM a private IP accessible only to your host laptop.

2. Boot the VM, log in, and find its IP address:
   ```bash
   ip -4 addr show
   ```
   Look for your network interface (e.g. `eth0` or `enp0s3`) and note the IPv4 address (e.g. `192.168.1.50`).

3. On your **laptop**, test that you can reach the VM:
   ```bash
   ping -c 3 <VM_IP>
   ssh <user>@<VM_IP>
   ```

---

## Step 2: Install Docker and Docker Compose on the VM

SSH into your VM and install the official Docker packages.

1. Update packages and install prerequisites:
   ```bash
   sudo apt-get update
   sudo apt-get install -y ca-certificates curl
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

5. Add your user to the `docker` group so you can run Docker without `sudo`:
   ```bash
   sudo usermod -aG docker "$USER"
   newgrp docker
   ```

6. Verify the installation:
   ```bash
   docker --version
   docker compose version
   ```

7. If you have `ufw` firewall enabled, allow HTTP, HTTPS, and SSH:
   ```bash
   sudo ufw allow OpenSSH
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   ```

---

## Step 3: Copy or Clone `acs-deploy` to the VM

Place the `acs-deploy` project into your home directory on the VM (`~/acs-deploy`).

**Option A — If your repo is on GitHub:**
```bash
git clone https://github.com/kevinrjones/KSCricketDeploy.git ~/acs-deploy
cd ~/acs-deploy
```

**Option B — Copy from your laptop via rsync:**
Run this on your **laptop**:
```bash
rsync -avz --exclude '.git' --exclude 'node_modules' \
  /Users/kevinjones/Dropbox/projects/cricket/acs-deploy/ \
  <user>@<VM_IP>:~/acs-deploy/
```

Then SSH into the VM:
```bash
ssh <user>@<VM_IP>
cd ~/acs-deploy
```

---

## Step 4: Configure the Environment File

The `.env` file defines image tags, hostnames, and database settings.

1. Copy the template to `environments/local-vm/.env`:
   ```bash
   cp .env.example environments/local-vm/.env
   ```

2. Open `environments/local-vm/.env` in an editor:
   ```bash
   nano environments/local-vm/.env
   ```

3. Review the settings. The defaults are already configured for local VM deployment:
   ```bash
   # Docker Images
   IDS_IMAGE=knowledgespike/acs-cricketarchive-ids:latest
   ADMINUI_IMAGE=knowledgespike/acs-cricketarchive-adminui:latest
   ACS_WEB_IMAGE=knowledgespike/acs-cricketarchive-web:latest
   ACS_API_IMAGE=knowledgespike/acs-cricketarchive-api:latest
   MARIADB_IMAGE=mariadb:11
   NGINX_IMAGE=nginx:stable-alpine

   # Hostnames for local VM routing
   IDS_HOSTNAME=ids-vm.knowledgespike.cricket
   ADMINUI_HOSTNAME=adminui-vm.knowledgespike.cricket
   WEB_HOSTNAME=web-vm.knowledgespike.cricket
   API_HOSTNAME=api-vm.knowledgespike.cricket

   # MariaDB App User
   MARIADB_DATABASE=identity
   MARIADB_USER=identity

   # ACS Web OIDC Credentials & Environment
   OIDC_CLIENT_ID=acsstats
   OIDC_CLIENT_SECRET=change-me-to-the-identity-client-secret
   KTOR_ENVIRONMENT=beta

   TZ=UTC
   ```

4. Set `OIDC_CLIENT_SECRET` to the client secret configured in IdentityServer for the `acsstats` client. Save and exit (`Ctrl+O`, `Enter`, `Ctrl+X`).

---

## Step 5: Generate and Configure Secret Files

Sensitive data (passwords, connection strings, license keys) are stored as individual files under `private/local-vm/` and mounted securely into `/run/secrets/` inside containers.

### Step 5.1: Run the automated secret generator

Run the included helper script to generate random secure passwords, matching database connection strings, and the Data Protection certificate:

```bash
chmod +x scripts/generate-local-vm-secrets.sh
./scripts/generate-local-vm-secrets.sh
```

This script automatically creates:
- `mariadb_root_password` — Random MariaDB root password.
- `mariadb_password` — Random password for the `identity` user.
- `ConnectionStrings__identity` — Connection string for IdentityServer pointing to MariaDB.
- `IdentityConnectionString` & `IdentityServerConnectionString` — Matching strings for AdminUI.
- `jdbc.username` (`cricketarchive`) & `jdbc.password` — Credentials for the ACS API.
- `DataProtection__Certificate__Password` & `certs/local-vm/ids-mysql-dp.pfx` — ASP.NET Data Protection encryption key.
- `AdminUIClientSecret` & `UsernamePolicy__Secret` — AdminUI operational credentials.

### Step 5.2: Set vendor license and credentials

`scripts/generate-local-vm-secrets.sh` pre-configures the active Duende AdminUI development license key. If you have your own commercial key or need to set Google OAuth:

```bash
# 1. Duende AdminUI License Key (if updating or replacing)
printf '%s' 'PASTE_YOUR_ADMINUI_LICENSE_KEY_HERE' > private/local-vm/LicenseKey

# 2. Google OAuth credentials (required by IdentityServer on boot) - look in the .microsoft/usersecrets
printf '%s' 'YOUR_GOOGLE_CLIENT_ID' > private/local-vm/Authentication__Google__ClientId
printf '%s' 'YOUR_GOOGLE_CLIENT_SECRET' > private/local-vm/Authentication__Google__ClientSecret

# 3. Set file permissions so container users (non-root $APP_UID) can read secrets
chmod 755 private/local-vm certs/local-vm
chmod 644 private/local-vm/*
chmod 644 certs/local-vm/ids-mysql-dp.pfx
```

---

## Step 6: Create TLS Certificates (Private CA)

Because your VM is on a local private IP, we use a local Certificate Authority (CA) to sign a certificate covering all four local hostnames.

1. Run the certificate generation script:
   ```bash
   chmod +x scripts/generate-local-vm-certs.sh
   ./scripts/generate-local-vm-certs.sh
   ```

2. This produces the following files in `certs/local-vm/`:
   - `dev-ca.crt` — The Root CA public certificate. **You will install this on your laptop.**
   - `dev-ca.key` — The private key for your CA.
   - `cacerts` — The Java truststore containing `dev-ca.crt` (mounted into JVM containers `acs-web` and `acs-api`).
   - `server.crt` — The SSL certificate configured for:
     - `ids-vm.knowledgespike.cricket`
     - `adminui-vm.knowledgespike.cricket`
     - `web-vm.knowledgespike.cricket`
     - `api-vm.knowledgespike.cricket`
     - `api-beta.knowledgespike.cricket` (used by `acs-web` internal BFF proxy routes in `beta` mode)
   - `server.key` — The private key for nginx TLS termination.

---

## Step 7: Configure Your Laptop (Hosts File & CA Trust)

Do this on your **host laptop** (macOS or Linux):

### Step 7.1: Update your laptop's `/etc/hosts` file

Open `/etc/hosts` on your laptop with sudo:
```bash
sudo nano /etc/hosts
```

Add this line (replace `<VM_IP>` with your VM's actual IP address from Step 1):
```text
<VM_IP>  ids-vm.knowledgespike.cricket adminui-vm.knowledgespike.cricket web-vm.knowledgespike.cricket api-vm.knowledgespike.cricket
```
Save and exit.

Test resolution from your laptop terminal:
```bash
ping -c 2 ids-vm.knowledgespike.cricket
```
It should reply from `<VM_IP>`.

### Step 7.2: Trust `dev-ca.crt` on your laptop

Because the VM uses self-signed TLS certificates issued by our local development CA, client browsers (Chrome, Safari, Edge) and CLI tools on your laptop will display **"Your connection is not private"** (`NET::ERR_CERT_AUTHORITY_INVALID`) until you install and trust `dev-ca.crt`.

If you are running from this repository on your laptop (or using a shared folder), the root certificate is already located at:
```text
certs/local-vm/dev-ca.crt
```
*(If you need to copy it from a remote VM, run: `scp <user>@<VM_IP>:~/acs-deploy/certs/local-vm/dev-ca.crt certs/local-vm/dev-ca.crt`)*

#### On macOS:

**Option A: Terminal Command (Fastest)**
From the project root on your laptop, run:
```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain certs/local-vm/dev-ca.crt
```

**Option B: Keychain Access GUI**
1. Open the certificate in Keychain Access:
   ```bash
   open certs/local-vm/dev-ca.crt
   ```
2. Select the **System** (or **login**) keychain.
3. Locate **KnowledgeSpike local-vm Dev CA** in the list and double-click it.
4. Expand the **Trust** section and set **When using this certificate** to **Always Trust**.
5. Close the window and authenticate with your macOS password.

> **CRITICAL — Restart Your Browser:**
> Fully quit (`Cmd + Q`) and relaunch your browser (Chrome, Safari, Edge, Brave). Browsers cache SSL certificate validation chains in memory; without a full restart, they will continue to show **"Your connection is not private"** even after the certificate is trusted.

#### On Linux (laptop):
```bash
sudo cp certs/local-vm/dev-ca.crt /usr/local/share/ca-certificates/dev-ca.crt
sudo update-ca-certificates
```

Now your laptop browsers and `curl` will trust the VM's HTTPS endpoints (`https://ids-vm...`, `https://web-vm...`, `https://adminui-vm...`, `https://api-vm...`) with a secure padlock.

---

## Step 8: Deploy the Application Stack

Back on your **VM**, start the containers:

1. Run the deployment script:
   ```bash
   cd ~/acs-deploy
   chmod +x scripts/deploy.sh
   ./scripts/deploy.sh local-vm
   ```

2. What `deploy.sh` does:
   - Pulls the latest container images.
   - Starts MariaDB, mounts `mariadb/init/01-init-databases.sh`, and initializes the `identity`, `cricketarchive`, and `cricket` databases automatically.
   - Starts IdentityServer, AdminUI, ACS Web, and ACS API.
   - Starts nginx on ports 80 and 443 with your TLS certificates.
   - Monitors container health checks until all services report healthy.

3. Verify running containers:
   ```bash
   cd ~/acs-deploy/environments/local-vm
   docker compose --env-file .env ps
   ```
   All 6 services (`mariadb`, `ids`, `adminui`, `acs-web`, `acs-api`, `nginx`) should show `Up` or `Up (healthy)`.

---

## Step 9: Verify Everything Works

### Step 9.1: Test health endpoints via curl

From your **laptop**, test each service over HTTPS:

```bash
# IdentityServer health endpoint
curl -fsS https://ids-vm.knowledgespike.cricket/health/ready && echo " -> IdS OK"

# AdminUI root page
curl -fsS -o /dev/null https://adminui-vm.knowledgespike.cricket/ && echo "AdminUI OK"

# ACS API health endpoint (Ktor heartbeat route)
curl -fsS https://api-vm.knowledgespike.cricket/heartbeat/alive && echo " -> API OK"

# ACS Web home page (sends GET; Ktor does not support HEAD requests)
curl -fsS -o /dev/null https://web-vm.knowledgespike.cricket/ && echo "ACS Web OK"
```

### Step 9.2: Test in your browser

1. Open **`https://ids-vm.knowledgespike.cricket`** in your browser:
   - You should see the IdentityServer landing page with a secure lock icon (no certificate warnings).
2. Open **`https://adminui-vm.knowledgespike.cricket`**:
   - You should see the AdminUI login and dashboard.
3. Open **`https://web-vm.knowledgespike.cricket`**:
   - Click login. It will redirect to `ids-vm.knowledgespike.cricket` for authentication, and return back to `web-vm.knowledgespike.cricket/signin-oidc`.

---

## Step 10: Import Cricket Data into MariaDB

The `cricketarchive` database contains all matches, players, teams, grounds, and statistics used by the ACS API (`acs-api`).

### Option A: Direct Command Line (Run on the VM)

From your **VM terminal**, stream the SQL dump into the running MariaDB container using `docker compose`:

```bash
cd ~/acs-deploy

# If using uncompressed SQL (e.g. from Parallels shared folder):
docker compose -f environments/local-vm/compose.yaml exec -T mariadb sh -c \
  'mariadb -u root -p"$(cat /run/secrets/mariadb_root_password)" --max-allowed-packet=1G cricketarchive' \
  < /media/psf/Dropbox/dumps/mysql/cricketarchive-upload.sql

# Or if using a gzipped dump:
gunzip -c /media/psf/Dropbox/dumps/mysql/cricketarchive-upload.sql.gz | docker compose -f environments/local-vm/compose.yaml exec -T mariadb sh -c \
  'mariadb -u root -p"$(cat /run/secrets/mariadb_root_password)" --max-allowed-packet=1G cricketarchive'
```

*Note: Alternatively, you can use the direct container name:*
```bash
docker exec -i acs-local-vm-mariadb-1 sh -c \
  'mariadb -u root -p"$(cat /run/secrets/mariadb_root_password)" --max-allowed-packet=1G cricketarchive' \
  < /media/psf/Dropbox/dumps/mysql/cricketarchive-upload.sql
```

### Option B: Using the Helper Script

A helper script is included in `scripts/import-cricket-data.sh` that dynamically optimizes MariaDB buffer sizes, auto-detects plain or gzipped files, and displays row count verification on completion:

```bash
cd ~/acs-deploy
chmod +x scripts/import-cricket-data.sh

# Run inside the VM (will auto-detect default backup path if omitted):
./scripts/import-cricket-data.sh /media/psf/Dropbox/dumps/mysql/cricketarchive-upload.sql local-vm
```

You can also run the import script directly from your **laptop** targeting the VM over SSH:
```bash
./scripts/import-cricket-data.sh ~/Dropbox/dumps/mysql/cricketarchive-upload.sql local-vm
```

### Step 10.1: Verify Cricket Data Import

Verify the imported tables and record counts from the VM:

```bash
cd ~/acs-deploy/environments/local-vm
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
curl -fsS https://api-vm.knowledgespike.cricket/heartbeat/alive && echo " -> API OK"
```

---

## Common Operations

### View live logs

On the VM:
```bash
cd ~/acs-deploy/environments/local-vm

# View logs for a specific service
docker compose --env-file .env logs -f ids
docker compose --env-file .env logs -f adminui
docker compose --env-file .env logs -f acs-api
docker compose --env-file .env logs -f acs-web
docker compose --env-file .env logs -f nginx
```

### Restart a single service

```bash
cd ~/acs-deploy/environments/local-vm
docker compose --env-file .env restart acs-web
```

### Stop and start the stack

```bash
cd ~/acs-deploy/environments/local-vm

# Stop all containers
docker compose --env-file .env down

# Start everything back up
docker compose --env-file .env up -d
```

### Back up the MariaDB databases

A backup script is included that dumps all databases (`identity`, `cricketarchive`, `cricket`) to a timestamped compressed archive:

```bash
cd ~/acs-deploy
chmod +x scripts/backup.sh
./scripts/backup.sh local-vm
```
Backups are saved to `backups/local-vm/`.

---

## Troubleshooting

| Symptom | Cause | Solution |
|---|---|---|
| **Browser: Server Not Found** | Laptop `/etc/hosts` missing entry or typo | Check `/etc/hosts` on laptop. Ensure the IP matches the VM IP. |
| **Browser: Connection Refused** | nginx not running or firewall blocking port 443 | On VM, check `docker compose ps`. Run `sudo ufw allow 80/tcp && sudo ufw allow 443/tcp`. |
| **Browser: "Your connection is not private" (`NET::ERR_CERT_AUTHORITY_INVALID`)** | `dev-ca.crt` not installed/trusted in laptop Keychain/system store, or browser was not restarted after import | Run `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain certs/local-vm/dev-ca.crt` on your laptop, then **fully restart your browser** (`Cmd + Q`). Alternatively, use Keychain Access GUI (set to Always Trust). |
| **IdentityServer fails on boot** | Missing Google OAuth credentials | Ensure `Authentication__Google__ClientId` and `Authentication__Google__ClientSecret` have values in `private/local-vm/`. |
| **AdminUI shows license error** | Missing or expired license | Check `private/local-vm/LicenseKey` file contents. |
| **AdminUI: Unable to connect to IdentityServer (SSL connection could not be established)** | AdminUI container does not trust the self-signed `dev-ca.crt` on `ids-vm` | Ensure `SSL_CERT_FILE: /run/certs/dev-ca.crt` and `certs/local-vm/dev-ca.crt:/run/certs/dev-ca.crt:ro` volume mount are present in `compose.yaml` under `adminui`, then recreate container: `docker compose up -d --force-recreate adminui`. |
| **ACS Web: oidc_metadata_unavailable (unable to find valid certification path to requested target)** | JVM container (`acs-web` / `acs-api`) does not trust the self-signed `dev-ca.crt` on `ids-vm` | Ensure `cacerts` was generated by `generate-local-vm-certs.sh` and mounted at `../../certs/local-vm/cacerts:/opt/java/openjdk/lib/security/cacerts:ro` in `compose.yaml` under `acs-web` and `acs-api`. |
| **ACS Web: 502 Bad Gateway / Unable to connect to the API server (`/api/...`)** | MariaDB credentials mismatch for `cricketarchive` user in `acs-api`, or stale access token cached in `acs-web` | Synchronize the `cricketarchive` password in MariaDB with `private/local-vm/jdbc.password`, then restart containers: `docker compose restart acs-api acs-web`. |
| **ACS Web: Proxy request failed (`No server host: api-beta... in the server certificate`)** | `server.crt` missing `api-beta.knowledgespike.cricket` SAN used by `acs-web` proxy routing in beta environment mode | Run `./scripts/generate-local-vm-certs.sh --force-server` to reissue `server.crt` with `api-beta.knowledgespike.cricket` SAN, copy to VM, and recreate nginx container (`docker compose up -d --force-recreate nginx`). |
| **OIDC Login: Redirect URI mismatch** | Client redirect URI in Identity doesn't match `https://web-vm...` | Log into AdminUI and verify that the `acsstats` client has `https://web-vm.knowledgespike.cricket/signin-oidc` registered as an allowed redirect URI. |
