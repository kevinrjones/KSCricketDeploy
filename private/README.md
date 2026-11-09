# Private secrets (gitignored content)

Each environment has a directory of **secret files**:

- `private/local-vm/` — laptop VM
- `private/beta/` — Netcup beta

Compose mounts each file to `/run/secrets/<filename>` (see `environments/*/compose.yaml` `secrets:`).

## Mental model

| Mechanism | What goes here | Who reads it |
|-----------|----------------|--------------|
| `environments/<env>/.env` | Image tags, hostnames, `STATS_OIDC_CLIENT_*`, `BBB_OIDC_CLIENT_*`, MariaDB *database name* / *user name* | Docker Compose substitution + a few plain env vars |
| `private/<env>/<file>` | Passwords, connection strings, license, Google OAuth, IdS SMTP settings | Containers via `/run/secrets` |
| `certs/<env>/` | TLS + Data Protection PFX | nginx / ids volumes |

**Rule:** the **entire file contents** are the secret value (no `KEY=` prefix). No trailing newline required; avoid extra spaces.

`private/.secret-names` is only a **cheatsheet of example lines** — it is **not** loaded by Compose. Real values are the individual files under `local-vm/` or `beta/`.

## Required files (local-vm / beta)

See the environment-specific secret tables in `README.md` and the deployment
guides. Generate local VM secrets with:

```bash
./scripts/generate-local-vm-secrets.sh
```

Generate Beta secrets with:

```bash
./scripts/generate-beta-secrets.sh
```

These scripts read any overrides from `environments/<env>/.env` (if defined) or generate random secure values. They populate the individual files in `private/<env>/` and generate the Data Protection certificate in `certs/<env>/ids-mysql-dp.pfx`.

For Beta email delivery, configure `MAILKIT_SMTP_*` in `environments/beta/.env` or replace the generated `MailKit__SmtpServer`,
`MailKit__Port`, `MailKit__Username`, and `MailKit__Password` files with the
SMTP settings used by the IdentityServer deployment. These files are mounted
by the Beta `ids` service; the `MailKit__Password` file should contain the
provider's app password where the SMTP account requires one, not a
`changeme-*` placeholder.

## Never commit

All secret files under `private/local-vm/` and `private/beta/` (except `.gitkeep`), `.env` files, and `certs/` are ignored by git.
Never commit real passwords, licenses, Google secrets, or connection strings to source control.
Refer to `AGENTS.md` for troubleshooting password and authentication issues.
