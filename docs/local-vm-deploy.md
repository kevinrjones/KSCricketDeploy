# Local VM deploy guide (laptop)

Step-by-step: run the **same** Compose stack as beta on a **Linux VM on your laptop**, reach it via **hosts file** (or split DNS), and use a **private CA / self-signed** certificate. This path does **not** use Cloudflare A records — a private LAN IP is not a public origin.

**Related:** [README — DNS and local VM](../README.md#dns-and-local-vm) · Identity `docs/deployment-advice.md` (Phase 5).

---

## What you will end up with

| Piece           | Value (defaults in this repo)                                                                       |
|-----------------|-----------------------------------------------------------------------------------------------------|
| Compose project | `environments/local-vm` (`name: acs-local-vm`)                                                      |
| Hostnames       | `ids-vm`, `adminui-vm`, `web-vm`, `api-vm` under `knowledgespike.cricket`                           |
| Name resolution | Laptop `/etc/hosts` (or macOS equivalent) → VM **LAN IP**                                           |
| TLS             | Private CA + server cert with those four names as SANs → `certs/local-vm/server.crt` + `server.key` |
| Edge            | nginx on VM ports **80/443** only                                                                   |
| Cloudflare      | **Not** used for A→private IP (optional Tunnel is out of scope for this guide)                      |

OIDC only works if **issuer, authority, redirects, and browser URL** all use the same `*-vm` hostnames.

---

## Prerequisites

### On the host laptop

- A hypervisor you already use (UTM, VirtualBox, VMware, Parallels, etc.)
- Ability to edit the hosts file (admin/sudo)
- `openssl` (macOS/Linux) if you generate certs on the laptop
- Optional: Docker Hub login if images are private

### On the Linux VM

- Fresh-ish Linux (Ubuntu 22.04/24.04 LTS is fine)
- Network in **bridged** or equivalent mode so the VM gets a **LAN IP** the laptop can reach (not only NAT-only with no port forwards)
- SSH access from the laptop
- ~4+ GB RAM recommended if Identity + AdminUI + ACS + MariaDB all run together

### Accounts / artifacts

- Published images (or tags you can pull):  
  `knowledgespike/ids`, `knowledgespike/adminui`,  
  `knowledgespike/acs-cricketarchive-web`, `knowledgespike/acs-cricketarchive-api`
- Real secret values for `private/local-vm/` (placeholders say `changeme` until you replace them)
- Duende / AdminUI license and client secrets as required by the apps

---

## Phase 0 — Create and network the VM

1. Create a Linux VM and install a desktop-optional server image.
2. Set networking so the VM is reachable from the laptop on a stable address, for example:
   - **Bridged** → DHCP LAN IP like `192.168.1.50`
   - or **host-only / shared** network with a fixed IP you control
3. On the VM, note the IP:

   ```bash
   hostname -I
   # or: ip -4 addr show
   ```

4. From the **laptop**, confirm connectivity:

   ```bash
   ping -c 2 <VM_LAN_IP>
   ssh <user>@<VM_LAN_IP>
   ```

5. (Optional but useful) Give the VM a static DHCP reservation on your router so the IP does not drift and break hosts entries.

---

## Phase 1 — Install Docker on the VM

On the VM (Ubuntu example):

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

sudo usermod -aG docker "$USER"
# log out and back in (or newgrp docker)
docker version
docker compose version
```

Open host firewall only as needed (if `ufw` is on):

```bash
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable   # if you use ufw
sudo ufw status
```

Do **not** publish MariaDB `3306` on the host.

If images are on a private Docker Hub account:

```bash
docker login
```

---

## Phase 2 — Get the deploy repo onto the VM

Pick one:

**A. Git clone (preferred once the repo is on GitHub)**

```bash
cd ~
git clone <YOUR_ACS_DEPLOY_GIT_URL> acs-deploy
cd acs-deploy
```

**B. Copy from the laptop** (repo still only local)

```bash
# on laptop — example
rsync -a --exclude '.git' \
  /Users/kevinjones/Dropbox/projects/cricket/acs-deploy/ \
  <user>@<VM_LAN_IP>:~/acs-deploy/
```

Then on the VM:

```bash
cd ~/acs-deploy
```

---

## Phase 3 — Environment file and secrets

### 3.1 `.env` for local-vm

```bash
cd ~/acs-deploy
cp .env.example environments/local-vm/.env
# or edit the existing environments/local-vm/.env
```

Set at least:

| Variable           | Example / notes                                                                               |
|--------------------|-----------------------------------------------------------------------------------------------|
| `IDS_IMAGE`        | Pin a tag/sha you trust, e.g. `knowledgespike/ids:sha-…` (avoid living on `latest` long-term) |
| `ADMINUI_IMAGE`    | Same                                                                                          |
| `ACS_WEB_IMAGE`    | `knowledgespike/acs-cricketarchive-web:…`                                                     |
| `ACS_API_IMAGE`    | `knowledgespike/acs-cricketarchive-api:…`                                                     |
| `IDS_HOSTNAME`     | `ids-vm.knowledgespike.cricket`                                                               |
| `ADMINUI_HOSTNAME` | `adminui-vm.knowledgespike.cricket`                                                           |
| `WEB_HOSTNAME`     | `web-vm.knowledgespike.cricket`                                                               |
| `API_HOSTNAME`     | `api-vm.knowledgespike.cricket`                                                               |
| `MARIADB_*`        | Match what you put in DB secrets / connection strings                                         |

Hostnames in `.env` must match:

- nginx `server_name`s in `nginx/local-vm.conf`
- OIDC public URLs inside app config / secrets
- names you put in the hosts file (Phase 5)

### 3.2 Replace secret placeholders

```bash
ls private/local-vm/
```

Replace every `changeme` (and empty) file with real values. Typical set:

- `mariadb_root_password`, `mariadb_password`
- `ids_connection_string` — must use Compose service name `mariadb` as host, not `localhost`, e.g. server=`mariadb`
- `ids_data_protection_password` + mount/use matching PFX if your image expects it (see app docs / Identity local secrets)
- Google client id/secret if used
- AdminUI license, client secret, authority-related settings as required
- ACS API/web secrets (OIDC client secret, connection strings, etc.)

Tighten permissions:

```bash
chmod 600 private/local-vm/*
```

**Never commit** real `private/**` or `environments/*/.env` (see `.gitignore`).

### 3.3 OIDC hostname checklist (local-vm)

Use **only** `*-vm` public URLs, for example:

- Identity public origin: `https://ids-vm.knowledgespike.cricket`
- AdminUI UI URL: `https://adminui-vm.knowledgespike.cricket`
- ACS authority / JWKS: `https://ids-vm.knowledgespike.cricket` (and JWKS path as your app expects)
- ACS redirect: `https://web-vm.knowledgespike.cricket/signin-oidc` (adjust path to match the app)

Register the same redirect URIs on the Identity client configuration for this environment.

---

## Phase 4 — Create TLS certificates (private CA)

nginx mounts:

- `certs/local-vm/server.crt`
- `certs/local-vm/server.key`

You need a certificate whose **SANs** include all four hostnames (and TLS that your browser will trust after you install the CA).

### Option A — Script in this repo (recommended)

On a machine with OpenSSL (laptop or VM), from the **acs-deploy** root:

```bash
chmod +x scripts/generate-local-vm-certs.sh
./scripts/generate-local-vm-certs.sh
```

This creates:

```text
certs/local-vm/
  dev-ca.crt      # install this in the laptop trust store
  dev-ca.key      # keep private; do not share
  server.crt      # nginx
  server.key      # nginx
```

Optional overrides:

```bash
./scripts/generate-local-vm-certs.sh \
  --domain knowledgespike.cricket \
  --days 825
# SANs: ids-vm / adminui-vm / web-vm / api-vm .<domain>
```

If you already generated certs and only need to refresh the server cert:

```bash
./scripts/generate-local-vm-certs.sh --force-server
```

Copy onto the VM if you generated on the laptop:

```bash
# from laptop
scp certs/local-vm/server.crt certs/local-vm/server.key \
  <user>@<VM_LAN_IP>:~/acs-deploy/certs/local-vm/
```

On the VM:

```bash
chmod 644 certs/local-vm/server.crt
chmod 600 certs/local-vm/server.key
```

Keep `dev-ca.crt` on the **laptop** for trust (Phase 5). You do not need the CA private key on the VM for day-to-day run.

### Option B — Manual OpenSSL (same outcome)

```bash
mkdir -p certs/local-vm
cd certs/local-vm

# CA
openssl genrsa -out dev-ca.key 4096
openssl req -x509 -new -nodes -key dev-ca.key -sha256 -days 825 \
  -out dev-ca.crt \
  -subj "/CN=KnowledgeSpike local-vm Dev CA/O=KnowledgeSpike"

# Server key + CSR
openssl genrsa -out server.key 2048
cat > server-ext.cnf <<'EOF'
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ids-vm.knowledgespike.cricket
DNS.2 = adminui-vm.knowledgespike.cricket
DNS.3 = web-vm.knowledgespike.cricket
DNS.4 = api-vm.knowledgespike.cricket
EOF

openssl req -new -key server.key -out server.csr \
  -subj "/CN=ids-vm.knowledgespike.cricket/O=KnowledgeSpike"

openssl x509 -req -in server.csr -CA dev-ca.crt -CAkey dev-ca.key \
  -CAcreateserial -out server.crt -days 825 -sha256 \
  -extfile server-ext.cnf

rm -f server.csr dev-ca.srl server-ext.cnf
chmod 600 server.key dev-ca.key
chmod 644 server.crt dev-ca.crt
```

### Data Protection PFX (Identity)

If your IdS image expects a DP certificate file (as in Identity local `compose`), generate or copy a PFX and wire it through secrets/volumes the same way as local Identity — password in `ids_data_protection_password`. This guide’s nginx cert is **separate** from the DP PFX.

---

## Phase 5 — Hosts file on the laptop (and trust the CA)

### 5.1 Hosts entries

Replace `192.168.x.x` with the real VM LAN IP.

**macOS / Linux (laptop)**

```bash
sudo ${EDITOR:-nano} /etc/hosts
```

Add one line (or four):

```text
192.168.x.x  ids-vm.knowledgespike.cricket adminui-vm.knowledgespike.cricket web-vm.knowledgespike.cricket api-vm.knowledgespike.cricket
```

Flush DNS cache if needed:

```bash
# macOS
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
```

**Windows (if you browse from Windows)**

`C:\Windows\System32\drivers\etc\hosts` — same four names → VM IP; run editor as Administrator.

### 5.2 Trust `dev-ca.crt` on the laptop

Until the CA is trusted, browsers show certificate errors and some OIDC flows misbehave.

**macOS (login keychain)**

```bash
# path to the CA you generated
security add-trusted-cert -r trustRoot -k ~/Library/Keychains/login.keychain-db \
  /path/to/acs-deploy/certs/local-vm/dev-ca.crt
```

Or: Keychain Access → import `dev-ca.crt` → set **When using this certificate: Always Trust** (SSL).

**Linux desktop (example)**

```bash
sudo cp dev-ca.crt /usr/local/share/ca-certificates/knowledgespike-local-vm.crt
sudo update-ca-certificates
```

Firefox may use its own store: Settings → Certificates → Import.

**curl tests** after trust (or use `--cacert`):

```bash
curl -vI https://ids-vm.knowledgespike.cricket/health/ready
```

### 5.3 Confirm resolution before Compose

```bash
# laptop
ping -c 1 ids-vm.knowledgespike.cricket
# should show VM_LAN_IP

getent hosts ids-vm.knowledgespike.cricket || dscacheutil -q host -a name ids-vm.knowledgespike.cricket
```

---

## Phase 6 — First deploy on the VM

From `~/acs-deploy` on the VM:

```bash
# sanity
test -f environments/local-vm/.env
test -f certs/local-vm/server.crt
test -f certs/local-vm/server.key
test -f nginx/local-vm.conf

./scripts/deploy.sh local-vm
```

Or manually:

```bash
cd environments/local-vm
docker compose --env-file .env pull
docker compose --env-file .env up -d
docker compose --env-file .env ps
docker compose --env-file .env logs -f nginx ids
```

Wait until healthchecks pass (`deploy.sh` waits up to ~5 minutes).

---

## Phase 7 — Verify from the laptop

```bash
# TLS + routing
curl -fsS -o /dev/null -w "%{http_code}\n" https://ids-vm.knowledgespike.cricket/health/ready
curl -fsS -o /dev/null -w "%{http_code}\n" https://adminui-vm.knowledgespike.cricket/
curl -fsS -o /dev/null -w "%{http_code}\n" https://api-vm.knowledgespike.cricket/health/ready
curl -fsS -o /dev/null -w "%{http_code}\n" https://web-vm.knowledgespike.cricket/
```

In the browser:

1. Open `https://ids-vm.knowledgespike.cricket` — lock icon, no warning (if CA trusted).
2. Open ACS web → login → confirm redirect host stays on `*-vm` names (no accidental `ids-beta` or `ids.local`).
3. AdminUI against the same IdS.

On the VM, if something fails:

```bash
cd ~/acs-deploy/environments/local-vm
docker compose --env-file .env ps
docker compose --env-file .env logs --tail=200 ids adminui acs-api acs-web nginx
```

---

## Day-2 operations

### Redeploy after new image tags

1. Edit `environments/local-vm/.env` image pins.
2. `./scripts/deploy.sh local-vm`

### Backup DB

```bash
./scripts/backup.sh local-vm
```

### Change VM IP

1. Update laptop `/etc/hosts`.
2. No Compose change required unless apps embedded the old IP (they should use hostnames only).

### Add another laptop client

1. Same hosts line → VM IP.  
2. Install the **same** `dev-ca.crt`.

---

## Troubleshooting

| Symptom                     | Likely cause                                         | What to try                                                                      |
|-----------------------------|------------------------------------------------------|----------------------------------------------------------------------------------|
| Browser: DNS not found      | Hosts not loaded / typo                              | Check `/etc/hosts`, flush DNS cache                                              |
| Browser: connection refused | Wrong IP, VM down, nginx not up                      | `ping` VM; `docker compose ps`; `ss -lntp \| grep -E ':80\|:443'` on VM          |
| Browser: cert warning       | CA not trusted or SAN missing hostname               | Re-import `dev-ca.crt`; regenerate server cert with all four SANs                |
| curl works, browser fails   | Browser DNS / different profile / Firefox store      | Check Firefox cert store; try Safari/Chrome                                      |
| OIDC redirect_uri mismatch  | Client config still beta/local                       | Align Identity client redirects with `web-vm…`                                   |
| Issuer mismatch             | `PublicOrigin` / authority still `ids.local` or beta | Fix env/secrets; restart ids + acs-*                                             |
| Mixed content / wrong host  | Page or API still pointing at another env            | Search config for `beta`, `ids.local`, `localhost`                               |
| Images pull fail            | Not logged in / tag missing                          | `docker login`; confirm tags on Hub                                              |
| MariaDB unhealthy           | Bad passwords / secret files                         | Check `private/local-vm/mariadb_*`; recreate volume only if you accept data loss |
| nginx fails to start        | Missing cert files or bad paths                      | `ls -la certs/local-vm/`; compose mount paths                                    |

### Confirms you are **not** on the Cloudflare path

- No orange-cloud A record to `192.168…`
- Laptop resolves `*-vm` to LAN IP (`ping` / `dig` should not show Cloudflare anycast IPs for that name if hosts is correct; hosts usually short-circuits before public DNS)

---

## Optional later: Cloudflare Tunnel

If you need **public** DNS or access off-LAN without a public IP:

1. Install `cloudflared` on the VM.  
2. Create a tunnel and Cloudflare CNAME routes for `ids-vm…` etc. to nginx.  
3. **Do not** create A records to the private IP.

Tunnel edge ≠ beta “proxy → origin 443”. This hosts+CA guide remains the default for LAN rehearsal. See README.

---

## Quick checklist

- [ ] VM has LAN IP; laptop can SSH/ping it  
- [ ] Docker + Compose plugin on VM  
- [ ] `acs-deploy` on VM  
- [ ] `environments/local-vm/.env` hostnames + image pins  
- [ ] `private/local-vm/*` real secrets, mode `600`  
- [ ] OIDC URLs all `*-vm`  
- [ ] `certs/local-vm/server.crt` + `server.key` (SANs for four names)  
- [ ] Laptop hosts → VM IP  
- [ ] Laptop trusts `dev-ca.crt`  
- [ ] `./scripts/deploy.sh local-vm` healthy  
- [ ] Browser OIDC login on ACS web works end-to-end  

---

## What this guide deliberately skips

- Cloudflare Full (strict) and origin certificates (beta/VPS only)  
- OpenTofu, automated GH Actions deploy to the VM  
- Publishing a custom nginx image  
- LocalCan/ngrok as the primary multi-hostname setup  
