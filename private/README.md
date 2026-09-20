# Private secrets (gitignored content)

Each environment has a directory of **secret files**:

- `private/local-vm/` — laptop VM
- `private/beta/` — Netcup beta

Compose mounts each file to `/run/secrets/<filename>` (see `environments/*/compose.yaml` `secrets:`).

## Mental model

| Mechanism | What goes here | Who reads it |
|-----------|----------------|--------------|
| `environments/<env>/.env` | Image tags, hostnames, `STATS_OIDC_CLIENT_*`, `BBB_OIDC_CLIENT_*`, MariaDB *database name* / *user name* | Docker Compose substitution + a few plain env vars |
| `private/<env>/<file>` | Passwords, connection strings, license, Google OAuth | Containers via `/run/secrets` |
| `certs/<env>/` | TLS + Data Protection PFX | nginx / ids volumes |

**Rule:** the **entire file contents** are the secret value (no `KEY=` prefix). No trailing newline required; avoid extra spaces.

`private/.secret-names` is only a **cheatsheet of example lines** — it is **not** loaded by Compose. Real values are the individual files under `local-vm/` or `beta/`.

## Required files (local-vm / beta)

See the table in `docs/local-vm-deploy.md` Phase 3. Generate placeholders with:

```bash
./scripts/generate-local-vm-secrets.sh
```

## Never commit

Real passwords, licenses, Google secrets, or connection strings. Placeholders may say `changeme`.
