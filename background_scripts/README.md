# CricketArchive maintenance runners

The files in this directory provide a portable maintenance workflow for the
CricketArchive data used by the ACS applications. They are intended to run both
on a development laptop and on the Beta VPS.

The workflow:

1. Fetches the latest grounds and scorecards.
2. Parses scorecards and player data into the local archive structure.
3. Updates players, officials, and the `cricketarchive` MariaDB database.
4. Creates a compressed SQL dump for backup or transfer.

The launchers and application binaries are safe to commit. Machine-specific
paths, account credentials, proxy credentials, and database passwords belong in
the ignored runtime configuration files described below.

## Quick start

Run these commands from the deployment checkout:

```bash
cd ~/acs-deploy
cp ca_scripts/config.env.example ca_scripts/config.env
cp ca_scripts/credentials.env.example ca_scripts/credentials.env
chmod 600 ca_scripts/config.env ca_scripts/credentials.env
$EDITOR ca_scripts/config.env ca_scripts/credentials.env
```

Edit at least the following values:

- `CA_ARCHIVE_DIR`: the CricketArchive `Archive` directory.
- `CA_DB_PASSWORD_FILE` or `CA_DB_PASSWORD`: the database password.
- `CRICKETARCHIVE_EMAIL` and `CRICKETARCHIVE_PASSWORD`: the account used by
  the fetch stages.

Then run the complete workflow:

```bash
./ca_scripts/run
```

The top-level runner also checks that the archive, fetch credentials, and
database password are available before starting. It does not require the
current working directory to be the repository root because every launcher
resolves its files from its own directory.

## Required software and permissions

The machine running the workflow needs:

- A Java runtime compatible with the checked-in CricketArchive application
  binaries.
- `mariadb-dump` or `mysqldump` for the final database export.
- `gzip` and standard POSIX shell utilities.
- Read/write access to `CA_ARCHIVE_DIR` and `CA_DUMP_DIR`.
- Network access to CricketArchive, directly or through the configured proxy.
- Network access to MariaDB using the host-side JDBC settings.

On the Beta VPS, the deployment user must also be able to run Docker commands.
The MariaDB container must be running before database update stages are used.

## Configuration files

### `config.env`

Start with `config.env.example`. It contains non-secret machine and database
settings. The main settings are:

| Variable | Purpose | Default/example |
| --- | --- | --- |
| `CA_ARCHIVE_DIR` | Root CricketArchive data directory | `$HOME/CricketArchive/Archive` |
| `CA_DUMP_DIR` | Directory for generated dumps | `$HOME/sql` |
| `CA_DUMP_FILE` | Full path of the compressed dump | `$HOME/sql/cricketarchive-upload.sql.gz` |
| `CA_DB_HOST` | MariaDB host reachable by the Java process | `127.0.0.1` |
| `CA_DB_PORT` | MariaDB port reachable by the Java process | `3307` on Beta |
| `CA_DB_NAME` | Database updated and exported | `cricketarchive` |
| `CA_DB_USER_FILE` | File containing the database username | `../private/beta/jdbc.username` |
| `CA_DB_PASSWORD_FILE` | File containing the database password | `../private/beta/jdbc.password` |
| `CA_DB_USER` | Direct username override | Usually loaded from `CA_DB_USER_FILE` |
| `CA_DB_PASSWORD` | Direct password override | Prefer a password file |
| `CA_JDBC_URL` | Complete JDBC URL override | Built from host, port, and database |

Relative secret-file paths are resolved relative to `ca_scripts`, not relative
to the directory from which the command happens to be launched. Absolute paths
are also supported.

### `credentials.env`

Put account and proxy values in `credentials.env` rather than in
`config.env`:

```text
CRICKETARCHIVE_EMAIL=
CRICKETARCHIVE_PASSWORD=
CRICKETARCHIVE_PROXY_HOST=
CRICKETARCHIVE_PROXY_PORT=
CRICKETARCHIVE_PROXY_USER=
CRICKETARCHIVE_PROXY_PASSWORD=
GMAIL_ACCT_PASSWORD=
```

`CRICKETARCHIVE_PROXY_HOST` and `CRICKETARCHIVE_PROXY_PORT` must be supplied
together. Leave both empty when a direct connection is permitted. The proxy
user and password are optional, depending on the proxy configuration.

`GMAIL_ACCT_PASSWORD` is only needed by application logging or notification
setups that use it; it is not required for the normal CricketArchive fetch.

### Environment overrides

Environment variables take precedence over defaults in the shared loader and
are useful for one-off runs or automation. For example:

```bash
CA_DUMP_FILE="$HOME/sql/cricketarchive-test.sql.gz" \
  ./ca_scripts/run
```

The loader also supports `CA_CONFIG_FILE` and `CA_CREDENTIALS_FILE` when a
different, protected configuration location is required:

```bash
CA_CONFIG_FILE=/etc/acs/ca-config.env \
CA_CREDENTIALS_FILE=/etc/acs/ca-credentials.env \
  ./ca_scripts/run
```

## Beta VPS setup

Beta Compose publishes MariaDB only on the VPS loopback interface. Containers
continue to use the Docker service address `mariadb:3306`, while these
host-side Java runners use `127.0.0.1:3307`.

### Install the runners in `/home/kevin/cron`

On the Beta VPS the scheduled job runs `/home/kevin/cron/run`, not the copy
under the deployment checkout. Replace the old runner set with the complete
contents of this directory; do not copy only the top-level `run` file. The
stage directories, `bin/` directories, and `lib/common.sh` are required:

Temporarily comment out the existing runner entry in `crontab -e`, or choose a
maintenance window when it cannot start, before synchronizing the tree. This
prevents cron from launching a partially replaced set of files.

```bash
cd ~/acs-deploy
tar -C /home/kevin -czf \
  "$HOME/cron-before-acs-runners-$(date +%Y%m%d%H%M%S).tar.gz" cron
rsync -a --delete \
  --exclude '/config.env' \
  --exclude '/credentials.env' \
  --exclude '/db.log' \
  --exclude '/cron.log' \
  --exclude '*/logs/' \
  --exclude '*/json.*' \
  --exclude '*/grounds*.json' \
  --exclude '*/Scorecards/' \
  --exclude '*/Scorecards.nightly/' \
  ca_scripts/ /home/kevin/cron/
```

The backup preserves the previous scripts, while the excluded runtime files
and generated data remain in place. If `/home/kevin/cron` contains unrelated
files, do not use `--delete` until those files have been moved elsewhere.
Restore or add the cron entry only after the replacement and configuration
checks below are complete.

Create the runtime configuration in the installed directory, rather than in
the Git checkout:

```bash
cp /home/kevin/cron/config.env.example /home/kevin/cron/config.env
cp /home/kevin/cron/credentials.env.example /home/kevin/cron/credentials.env
chmod 600 /home/kevin/cron/config.env /home/kevin/cron/credentials.env
$EDITOR /home/kevin/cron/config.env /home/kevin/cron/credentials.env
```

Because `/home/kevin/cron` is not inside `~/acs-deploy`, use absolute paths for
the deployment secret files in `config.env`:

```bash
CA_DB_USER_FILE=/home/kevin/acs-deploy/private/beta/jdbc.username
CA_DB_PASSWORD_FILE=/home/kevin/acs-deploy/private/beta/jdbc.password
```

Use absolute paths for `CA_ARCHIVE_DIR`, `CA_DUMP_DIR`, and `CA_DUMP_FILE` too;
this avoids relying on the environment supplied by cron.

After pulling the deployment changes, start or recreate MariaDB:

```bash
cd ~/acs-deploy
docker compose --env-file environments/beta/.env \
  -f environments/beta/compose.yaml up -d mariadb
```

The standard Beta `config.env.example` expects:

- Archive data in `$HOME/CricketArchive/Archive`.
- Generated dumps in `$HOME/sql`.
- Database credentials in `../private/beta/jdbc.username` and
  `../private/beta/jdbc.password`.
- MariaDB at `jdbc:mariadb://127.0.0.1:3307/cricketarchive`.

If the VPS uses a different directory layout, change the paths in
`/home/kevin/cron/config.env`; do not edit the committed example just for one
host.

### Cron entry

Use an absolute executable path and an explicit `PATH`; cron does not provide
the same environment as an interactive shell. For example, edit the
deployment user’s crontab with `crontab -e`:

```cron
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/bin

15 2 * * * /home/kevin/cron/run >>/home/kevin/cron/cron.log 2>&1
```

The runner itself writes database-export diagnostics to
`/home/kevin/cron/db.log`. Ensure the cron user can read the archive, read the
Beta JDBC secret files, execute Docker-related commands if needed by the
deployment, and connect to `127.0.0.1:3307`. Do not put passwords in the
crontab line.

### Rotate the cron logs

Install this as `/etc/logrotate.d/acs-cron` on the VPS. The `su` directive is
required when `/home/kevin/cron` is writable by `kevin`; without it, logrotate
skips the files with an insecure-parent-directory warning:

```text
/home/kevin/cron/cron.log /home/kevin/cron/db.log {
    daily
    rotate 14
    missingok
    notifempty
    compress
    delaycompress
    dateext
    create 0640 kevin kevin
    su kevin kevin
}
```

Create or replace the file as root, then check the parent-directory ownership
and test the configuration without changing any logs:

```bash
sudo install -o root -g root -m 0644 /dev/stdin /etc/logrotate.d/acs-cron <<'EOF'
/home/kevin/cron/cron.log /home/kevin/cron/db.log {
    daily
    rotate 14
    missingok
    notifempty
    compress
    delaycompress
    dateext
    create 0640 kevin kevin
    su kevin kevin
}
EOF

namei -l /home/kevin/cron/cron.log
sudo logrotate -d /etc/logrotate.d/acs-cron
```

The directory should be owned by `kevin` and must not be writable by an
unrelated group or by everyone. If it is, correct only that directory after
confirming no shared service depends on the current mode:

```bash
sudo chown kevin:kevin /home/kevin/cron
chmod 0755 /home/kevin/cron
```

To perform an immediate rotation after the dry run, use:

```bash
sudo logrotate -f /etc/logrotate.d/acs-cron
ls -lh /home/kevin/cron/cron.log*
ls -lh /home/kevin/cron/db.log*
```

## What the complete runner does

`run` invokes the stages in this order. When installed on Beta, the command is
`/home/kevin/cron/run`:

| Order | Stage | Role |
| ---: | --- | --- |
| 1 | `sa-getgrounds` | Fetches ground data, using the optional proxy settings. |
| 2 | `sa-getcards-nightly` | Fetches nightly scorecards into the archive. |
| 3 | `sa-parsecard` | Parses nightly scorecards into JSON data. |
| 4 | `sa-parseplayer` | Parses player and official data into JSON data. |
| 5 | `sa-update-players` | Updates database player data through JDBC. |
| 6 | `sa-update-officials` | Updates database official data through JDBC. |
| 7 | `sa-database` | Performs the broader database update from the archive. |
| 8 | database dump | Exports `CA_DB_NAME` and compresses it to `CA_DUMP_FILE`. |

The dump is first written to a temporary uncompressed file and is only
published to `CA_DUMP_FILE` after `mariadb-dump` or `mysqldump` succeeds. The
temporary file is removed when the command completes or is interrupted.

The top-level database export writes verbose diagnostics to `db.log` beside
the top-level `run` file. Review `/home/kevin/cron/db.log` on Beta when the
final dump step reports an error.

## Running an individual stage

Each stage has its own `run` launcher. This is useful when retrying one failed
operation or when validating a new archive before running the full cycle:

```bash
./ca_scripts/sa-getgrounds/run
./ca_scripts/sa-getcards-nightly/run
./ca_scripts/sa-parsecard/run
./ca_scripts/sa-parseplayer/run
./ca_scripts/sa-update-players/run
./ca_scripts/sa-update-officials/run
./ca_scripts/sa-database/run
```

On Beta, use the corresponding paths under `/home/kevin/cron`, for example:

```bash
/home/kevin/cron/sa-database/run
```

Stages that update MariaDB require `CA_DB_PASSWORD` or
`CA_DB_PASSWORD_FILE`. Fetch and parse stages require the archive directory;
the complete runner additionally requires the CricketArchive account
credentials.

When running a stage by itself, remember that it may depend on files produced
by an earlier stage. For example, parsing a scorecard requires the scorecard
to have already been fetched, and database updates require the corresponding
JSON output to exist.

## JDBC and Docker networking

The Java applications in `ca_scripts` run on the host, not inside the Compose
network. Therefore this URL will not work from the VPS host:

```text
jdbc:mariadb://mariadb:3306/cricketarchive
```

`mariadb` is Docker-network DNS and is resolvable only by containers attached
to the Beta network. The host-side URL is:

```text
jdbc:mariadb://127.0.0.1:3307/cricketarchive
```

Do not change it to `localhost:3306` unless a native MariaDB server is actually
running on port `3306`. If port `3307` is already occupied:

1. Set `MARIADB_HOST_PORT` in `environments/beta/.env`.
2. Set the same port as `CA_DB_PORT` in `/home/kevin/cron/config.env`.
3. Recreate the MariaDB service so the new mapping is active.
4. Confirm that the runner's JDBC URL uses the new port before updating data.

The loopback binding prevents the database port from being exposed directly to
the public network. Do not replace `127.0.0.1` with `0.0.0.0` unless there is a
specific, reviewed network-security requirement.

## Checking a setup before a full run

Use these checks before starting a potentially long fetch and update cycle:

```bash
test -d "$HOME/CricketArchive/Archive"
test -r ca_scripts/config.env
test -r ca_scripts/credentials.env
test -r private/beta/jdbc.username
test -r private/beta/jdbc.password
command -v mariadb-dump || command -v mysqldump
```

For the installed Beta runner, use its absolute paths instead:

```bash
test -x /home/kevin/cron/run
test -r /home/kevin/cron/config.env
test -r /home/kevin/cron/credentials.env
test -r /home/kevin/acs-deploy/private/beta/jdbc.username
test -r /home/kevin/acs-deploy/private/beta/jdbc.password
```

On Beta, also check the rendered MariaDB mapping from the repository root:

```bash
docker compose --env-file environments/beta/.env \
  -f environments/beta/compose.yaml config
```

A safe configuration failure is preferable to starting the workflow with an
empty archive path or an incorrect database. If a required value is missing,
the launchers print the relevant variable name and exit before invoking the
application binary.

## Troubleshooting

### `CricketArchive directory does not exist`

Set `CA_ARCHIVE_DIR` to the directory that contains the archive's `Players`,
`Scorecards`, and related data directories. The default is
`$HOME/CricketArchive/Archive`.

### Fetch authentication fails

Check `CRICKETARCHIVE_EMAIL` and `CRICKETARCHIVE_PASSWORD` in the ignored
`credentials.env`. Do not put them in a launcher or paste them into a ticket,
log, or documentation file. If the site is only reachable through a proxy,
set both proxy host and port, plus the proxy credentials when required.

### JDBC connection refused

Confirm that the MariaDB container is running, that the Beta port mapping is
active, and that `CA_DB_PORT` matches `MARIADB_HOST_PORT`. From the VPS, the
expected endpoint is `127.0.0.1:3307`; `mariadb:3306` is only for Dockerized
clients.

### Access denied or missing database

Check that the username and password files point to the same credentials used
by the Beta deployment and that `CA_DB_NAME=cricketarchive`. A successful TCP
connection does not prove that the configured user has permissions on the
target database.

### Database export fails

Check `db.log` beside the installed `run` file (on Beta,
`/home/kevin/cron/db.log`), confirm that `mariadb-dump` or `mysqldump` is
installed, and verify that `CA_DUMP_DIR` is writable and has enough free
space. The previous dump is not replaced when the export or compression step
fails.

### A stage fails after a partial run

Inspect the stage output and the generated archive/JSON files, correct the
underlying configuration or data issue, and rerun the affected stage. Run the
full workflow again only when the prerequisite files and database state are
valid.

## Source-control and credential safety

`config.env` and `credentials.env` are ignored by Git. The `*.example` files,
launchers, shared library, and documentation are the files intended for source
control. Before committing changes, check:

```bash
git status --short
git diff --check
```

Never commit CricketArchive, proxy, SMTP, or database passwords. Avoid putting
secrets in shell history and process arguments where possible; the database
password-file settings are preferred over `CA_DB_PASSWORD`.

Credentials that were embedded in older laptop launchers may remain in Git
history. Rotate those credentials independently before using the VPS copy, and
do not assume removing the current plaintext is sufficient if the credentials
were ever pushed to a shared repository.