# CRM deployment on Netcup

Production URL: https://crm.angar-velocafe.com

Server: `152.53.156.254`, Debian 13, AMD64, 8 GiB RAM, 4 CPUs.
The existing website is the Compose project in `/opt/veloangar`. Its Caddy
container (`angar-caddy`) owns ports 80/443 and handles the website and CMS.

## Isolation

CRM files live in `/opt/angar-crm`, Compose project name `angar-crm`.
The web container joins `veloangar_default` so Caddy can reach `crm-web:3000`.
Only the CRM web container joins that network; its PostgreSQL and worker use
the CRM's internal network. No CRM host ports are published.

PostgreSQL 17 has its own volume and Ukrainian locale. It does not use the
website's `angar-postgres` database. Uploads have their own persistent volume.
Web, worker and database have memory/CPU limits and rotated Docker logs.

There is one Puma process. Cable is in-process because the app currently uses
no realtime broadcast subscriptions. Solid Queue uses the CRM database and a
separate worker for durable Active Storage jobs.

## First installation

1. Add the Namecheap A record `crm` → `152.53.156.254`.
2. Copy `deploy/` to `/opt/angar-crm/deploy/`. Make its scripts executable.
3. Create `/opt/angar-crm/production.env` from `deploy/production.env.example`,
   owned by root with mode `600`. Use independent random database and Rails
   secret values. This file must never be committed or included in an image.
4. Supply `SEED_OWNER_PASSWORD` and `SEED_VIKTOR_PASSWORD` for the initial
   accounts. Their email addresses remain login identifiers; no email is sent.
5. Build the CRM-only database image:

   ```bash
   cd /opt/angar-crm
   CRM_IMAGE=angar-crm:bootstrap docker compose --project-name angar-crm \
     --env-file production.env -f deploy/compose.yml build crm-db
   ```

6. Load the tested AMD64 app image, tagged `angar-crm:<commit-sha>`, using
   `docker save` on the build machine and `docker load` on the server.
7. Run `/opt/angar-crm/deploy/release <commit-sha>`. This initializes a fresh
   database with two owners and the catalog, then checks web and worker health.
   Existing local test data is not transferred. Seeds only initialize missing
   records; they never reset existing passwords, roles, or catalog prices.
8. Back up `/opt/veloangar/Caddyfile`, then append `deploy/Caddyfile.crm` to it.
   Preserve the original file's inode because it is bind-mounted into Caddy.
   Validate before applying:

   ```bash
   docker exec angar-caddy caddy validate --config /etc/caddy/Caddyfile
   docker exec angar-caddy caddy reload --config /etc/caddy/Caddyfile
   ```

   If validation fails, restore the file contents and leave the running Caddy
   configuration alone. Caddy obtains and renews the CRM's HTTPS certificate.
   Verify all three domains after reload: website, CMS, and CRM.
9. Remove the two seed-password variables from `production.env` after saving
   the initial credentials in a password manager. Recreate CRM web/worker to
   remove those variables from their environments. Keep `SECRET_KEY_BASE`
   stable across releases; changing it invalidates sessions and signed URLs.

## GitHub deployment

`.github/workflows/deploy.yml` runs for pushes to `master` and manual dispatch.
It runs the reusable CI workflow first: Ruby tests, browser tests, lint and
security scans. It builds the AMD64 app image on GitHub and streams a compressed
image to the server over SSH. No container registry credentials are needed.

Create a dedicated Ed25519 key for GitHub, separate from your personal key.
Install its public key in root's `authorized_keys` with this prefix:

```text
restrict,command="/opt/angar-crm/deploy/receive" ssh-ed25519 PUBLIC_KEY github-crm-deploy
```

The forced command accepts only `deploy <40-character SHA>` and an archive
containing exactly that CRM image tag. It cannot be used for an interactive
shell or port forwarding. The account can deploy trusted application code;
protect the repository and production branch accordingly.

GitHub environment `production` needs:

- Secret `CRM_SSH_KEY`: the dedicated private key.
- Secret `CRM_KNOWN_HOSTS`: the verified server's full SSH host-key record.
- Repository variable `CRM_DEPLOY_ENABLED=true`, set after first installation.

The verified ED25519 server fingerprint is
`SHA256:C42XsOuYS5i5HwOUjDnwur2HabrHtEdj6Kx0kzFVX+w`.
Do not replace host-key verification with unchecked `ssh-keyscan` at deploy time.

The deployment script locks deployments/backups, pauses only the CRM, takes a
consistent pre-migration backup, prepares the database, starts the new image,
and verifies worker heartbeat and the login page. There is a brief CRM outage
during this simple single-instance rollout. The website and CMS keep running.

Infrastructure files in `/opt/angar-crm/deploy/` are installed separately from
app images. Changes to Compose, PostgreSQL, Caddy or deployment scripts require
an explicit infrastructure update. Ordinary app pushes update the image only.

## Backups and recovery

`deploy/backup` writes PostgreSQL custom-format dumps and compressed uploads to
`/opt/angar-crm/backups/<UTC timestamp>/`, with owner-only permissions. Call it
while CRM web/worker are stopped for a consistent pair. It validates archive
readability before reporting success.

Schedule `/opt/angar-crm/deploy/nightly-backup` in root's crontab outside shop
hours. It uses the same deployment lock, pauses CRM web/worker, backs up and
restarts them even on failure. Schedule timezone is the server's timezone.

These copies are on the same server. Copy them to an independent destination
and set retention before relying on them for real shop data. Also keep a secure
copy of `production.env`; the database dump does not contain Rails secrets.

For restore, first stop CRM web/worker, preserve the current database/files as
a separate backup, restore the selected SQL dump with `pg_restore` into the
CRM database and unpack the matching upload archive into the CRM upload volume.
Start the app image named in the backup's `release` file. Never restore into
the website's database or storage. Test restoration periodically.

`current-release` records the last successful app SHA. Previous images are
retained. On failed deployment the script attempts to restart the previous
image; this does not undo database migrations. Destructive migrations may
require a matching database/file restore. Do not use global Docker pruning or
`docker compose down -v` on this shared server.

## Operations

```bash
cd /opt/angar-crm
export CRM_IMAGE="angar-crm:$(cat current-release)"
docker compose --project-name angar-crm --env-file production.env -f deploy/compose.yml ps
docker compose --project-name angar-crm --env-file production.env -f deploy/compose.yml logs --tail 100 crm-web crm-worker
```

`/up` checks Rails boot. The release additionally checks database access, the
login page and the worker. Monitor public HTTPS, disk usage, worker health,
failed jobs and backup completion. Owner-managed passwords replace email reset.
All attachment endpoints require an active staff session and use private cache
headers, including the otherwise public Active Storage disk/variant URLs.
