# Fly.io → shared Hetzner host, SQLite → PostgreSQL — migration plan

Moves Lurepedia off Fly.io onto the box that already serves Wunderkind
(`89.167.69.250`, `wunderkind.bg`), onto that host's shared PostgreSQL 17.
No spec — this is infrastructure, not a feature.

## What the target host actually is

Not Kamal. `wunderkind/config/deploy.yml` describes a Kamal deployment that is
**not what runs** — the box is Docker Compose behind a shared Caddy, laid out
and documented in `/opt/infra/README.md`:

    /opt/infra/caddy/       shared reverse proxy, TLS for every domain (conf.d/*.caddy)
    /opt/infra/postgres/    shared PG 17, one role + database per project
    /opt/infra/backup.sh    nightly pg_dump per database + *_storage volumes, 14 days
    /opt/apps/<project>/    src/ checkout, .env (600), compose.yaml, deploy.sh

    edge      Caddy <-> apps      internal   apps <-> Postgres

Capacity: 4 vCPU, 7.6 GB RAM (6.5 GB free), 75 GB disk (62 GB free), **x86_64**,
IPv6 `2a01:4f9:c015:5b3a::1`. Postgres holds one 44 MB database today and is
published only on `127.0.0.1:5432`. `max_connections=100`, `shared_buffers=1GB`.

The host is built for this: `/opt/infra/new-project-db.sh <project>` provisions a
role + database + credentials file, and the README documents a pre-DNS smoke test
(`tls internal` + `curl --resolve`). Adding an app is a documented path, not a
new invention.

## What we are actually moving

Measured on production, 2026-09-02:

| | |
|---|---|
| `production.sqlite3` | 79 MB (+4 MB WAL) |
| `production_queue.sqlite3` | 28 MB — finished job history, **discard** |
| `production_cache` / `production_cable` | 40 KB each — ephemeral, **discard** |
| rows | brands 71, lures 2030, variants 26516, builds 4587, users 6, revisions 285, moderation 5 |
| rows (Active Storage) | blobs 106098, attachments 106098, variant_records 79885 |
| catches / comments | **0 / 0** |

Two findings that shrink this job a lot:

1. **Active Storage is already on Tigris** — `service_name` is `tigris` for
   **all 106,098 blobs**, zero on `local`, and `/rails/storage` holds no blob
   directories. 7.25 GB of objects **do not move**; only the five `AWS_*` /
   `BUCKET_NAME` env vars do. Note `CLAUDE.md` still describes the volume as
   holding "local Active Storage uploads" — stale.
2. **No SQLite-specific SQL.** No FTS, no `PRAGMA`, no `julianday`, no
   `find_by_sql`. The only hand-written SQL is `LOWER(col) LIKE ?` in
   `BrandFilter`/`ShopFilter`/`LureFilter`/`FilterOptionsController`, which is
   portable and, because it lowercases both sides, keeps its behaviour on PG
   (where `LIKE` is case-sensitive and SQLite's was not).

Schema portability checked: only `integer/bigint/string/text/datetime/boolean/
json/decimal` columns, and the 32 `add_foreign_key` constraints are int4 columns
referencing bigint PKs — a SQLite-era artifact. **Verified against real PG**: an
int4 → int8 foreign key is accepted and inserts fine, so `db/schema.rb` loads
as-is.

Lurepedia needs **no persistent volume at all** after this: SQLite is gone,
Active Storage is remote. `backup.sh` picks the new databases up automatically
(it enumerates `pg_database`) and finds no `*_storage` volume, which is correct.

## Phase 0 — two decisions to make first

1. **Tigris stays or goes.** It is S3 over HTTPS and works from any host, but it
   is provisioned through Fly and billed to that org. Recommendation: **keep it**
   (zero risk, zero data movement) and do not destroy the Fly *organisation*
   when the app goes — only the app and its volume. Revisit later if you want
   storage and compute with one vendor; that would be a separate 7.25 GB /
   106k-object copy.
2. **Resource policy.** Lurepedia ran on 4 GB with CPU-heavy in-Puma image jobs.
   Both apps plus PG now share 4 vCPU / 7.6 GB. Recommendation: set `mem_limit`
   and `cpus` on both app services, keep `SOLID_QUEUE_IN_PUMA=true` but cap
   worker concurrency, and run catalog imports off-peak.

## Phase 1 — make the app PostgreSQL-capable (repo, one PR)

1. **Gemfile**: add `gem "pg", "~> 1.6"`. Keep `sqlite3` for now — the dry-run
   copy in Phase 2 needs both adapters. Drop it in Phase 5.
2. **`config/database.yml`**: rewrite for PG. Production mirrors the house
   pattern (`wunderkind/config/database.yml`): `adapter: postgresql`, and
   `database`/`host`/`username`/`password` from `POSTGRES_DB`/`DB_HOST`/
   `POSTGRES_USER`/`POSTGRES_PASSWORD`, which is exactly what
   `new-project-db.sh` writes. **Keep all four entries** (primary, cache, queue,
   cable) pointing at four separate databases — collapsing them onto one
   database makes the four `schema_migrations`/`ar_internal_metadata` tables
   collide. Dev/test become `lurepedia_development` / `lurepedia_test` (+ the
   three secondaries per env).
3. **Dockerfile**: runtime line — drop `sqlite3`, add `postgresql-client`;
   build line — add `libpq-dev`. **Keep `imagemagick`** (`variant_processor =
   :mini_magick`) and `libvips`; do not copy Wunderkind's package list wholesale,
   it has neither.
4. **`config/environments/production.rb`**: `config.hosts` → `lurepedia.com`,
   `www.lurepedia.com`; drop `lurepedia.fly.dev`. Keep `assume_ssl` +
   `force_ssl` (Caddy terminates TLS and its `trusted_proxies static
   private_ranges` makes `X-Forwarded-Proto` trustworthy) and keep both `/up`
   exclusions — the compose healthcheck hits it over plain HTTP on localhost.
5. **Local PG**: `bin/rails db:prepare`, `bin/rails test`, `bin/rubocop`,
   `bin/ci`. Boot the app on an empty PG and click through. Regenerate
   `db/schema.rb` from PG and commit it.
6. Leave `fly.toml` in place until Phase 5.

Optional follow-up, not part of the cutover: a migration turning the 6 `json`
columns into `jsonb`.

## Phase 2 — dry-run the data migration locally (no production risk)

1. **Consistent snapshot** — a raw `cp` would miss the 4 MB WAL. On the Fly
   machine, as the `rails` user:

       sqlite3 /rails/storage/production.sqlite3 "VACUUM INTO '/tmp/snap.sqlite3'"

   then `fly ssh sftp get /tmp/snap.sqlite3`.
2. Create the four local PG databases and `bin/rails db:schema:load` (all four),
   so **Rails owns the schema**, not the copy tool.
3. Copy data only, into the Rails-made schema:

       pgloader --with "data only" --with "truncate" --with "disable triggers" \
         sqlite:///path/snap.sqlite3 postgresql:///lurepedia_development

   Fallback if pgloader misbehaves on the boolean/datetime casts: a Ruby script
   holding two AR connections and `insert_all`-ing each table in batches — the
   data is small enough that either finishes in minutes.
4. **Reset every sequence.** This is the single most likely way to ship a broken
   migration: rows arrive with explicit ids, the sequences stay at 1, and the
   first `create` collides.

       ActiveRecord::Base.connection.tables.each { |t| ActiveRecord::Base.connection.reset_pk_sequence!(t) }

5. **Verify**: row count per table against the table above; then spot-check the
   8 boolean columns (`uv_glow` and friends) are `true/false` not `0/1`, a few
   `datetime`s round-trip in UTC, and the 6 `json` columns parse.
6. Boot against the copy: a lure page with images (proves Tigris + blob rows),
   `/design-system`, a `LureFilter` search, the moderation queue, sign-in,
   pagination, and one locale other than `en`.
7. **Note the collation change**: SQLite sorted `BINARY`, PG sorts `en_US.utf8`.
   Alphabetical brand/lure lists may reorder around case and diacritics.
   Cosmetic — but look at a brand index once so it is a known change, not a
   surprise bug report.

## Phase 3 — provision the host and smoke-test before DNS

1. **Databases** (creates role `lurepedia`, `lurepedia_production`, and
   `/opt/infra/postgres/credentials/lurepedia.env`):

       /opt/infra/new-project-db.sh lurepedia
       for db in cache queue cable; do
         docker exec postgres createdb -U postgres -O lurepedia "lurepedia_${db}"
       done

2. **App directory** `/opt/apps/lurepedia/`: `git clone` into `src/`, then
   `compose.yaml` copied from Wunderkind's with `container_name: lurepedia-web`,
   both external networks, the same healthcheck and log rotation, **no volume**,
   plus the Phase 0 memory/CPU limits.
3. **`.env`** (mode 600) = the credentials file, plus:
   `RAILS_ENV=production`, `RAILS_MAX_THREADS=3`, `RAILS_LOG_LEVEL=info`,
   `TZ=Europe/Sofia`, `SOLID_QUEUE_IN_PUMA=true`, and the six secrets read off
   the live Fly machine (`fly ssh console -a lurepedia -C printenv` — Fly secrets
   are write-only through the API, so this is the way to recover them):
   `RAILS_MASTER_KEY`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`,
   `AWS_ENDPOINT_URL_S3`, `AWS_REGION`, `BUCKET_NAME`.
   **Do not set `HTTP_PORT`** — Thruster's default 80 is what the host convention
   proxies to, and Wunderkind proves the non-root container binds it here.
4. **`deploy.sh`**: copy Wunderkind's verbatim, changing the paths and
   `lurepedia-web`. It fetches, builds, `up -d`, waits on the healthcheck; the
   entrypoint's `db:prepare` applies migrations on boot.
5. **Smoke test with a copy of the data, before touching DNS.** Load the Phase 2
   snapshot into `lurepedia_production`, bring the app up, and use the README's
   SNI trick:

       cat > /opt/infra/caddy/conf.d/00-smoketest.caddy <<'EOF'
       lure.local { tls internal
                    reverse_proxy lurepedia-web:80 }
       EOF
       docker exec caddy caddy reload --config /etc/caddy/Caddyfile
       curl -k --resolve lure.local:443:89.167.69.250 https://lure.local/up

   Walk the Phase 2 checklist against it. `config.hosts` will reject `lure.local`
   for anything but `/up`, so either add it temporarily or drive the check with a
   `Host: lurepedia.com` header. Then **delete the file and reload**.

## Phase 4 — cutover (~20 minutes of downtime)

Downtime is cheap here: 6 users, all staff, no catches and no comments. Still do
it deliberately.

1. Confirm DNS TTL is 300s — **it already is** (`lurepedia.com A 300`).
2. **Check nothing is in flight**, or it dies with the queue database:

       fly ssh console -a lurepedia -C "bin/rails runner 'puts SolidQueue::Job.where(finished_at: nil).count'"

   Drain to zero before continuing.
3. **Stop writes**: `fly machine stop <id> -a lurepedia`. This guarantees the
   snapshot is final — the alternative (a maintenance page) is more work for the
   same result at this size.
4. Start the machine read-only-in-practice just long enough to take the final
   `VACUUM INTO` snapshot, download it, stop again. (Or take the snapshot in
   step 2 and accept that a few seconds of writes could follow — with staff-only
   write traffic, coordinate rather than engineer.)
5. On the host: truncate/recreate `lurepedia_production`, `db:schema:load`,
   pgloader data-only, **reset sequences**, verify counts.
6. `/opt/apps/lurepedia/deploy.sh main`; wait for healthy; re-run the smoke test.
7. **Namecheap** (BasicDNS), apex and `www`:
   `A → 89.167.69.250`, `AAAA → 2a01:4f9:c015:5b3a::1`. Both records need
   changing — the current AAAA points at Fly, so leaving it would break IPv6
   clients.
8. **Caddy site file**, matching the house pattern (apex canonical, per
   `default_url_options`):

       cat > /opt/infra/caddy/conf.d/lurepedia.caddy <<'EOF'
       www.lurepedia.com { redir https://lurepedia.com{uri} permanent }
       lurepedia.com { import common
                       reverse_proxy lurepedia-web:80 }
       EOF
       docker exec caddy caddy reload --config /etc/caddy/Caddyfile

   Caddy issues the Let's Encrypt certificate itself once the A record resolves
   here; port 80 is open for the HTTP-01 challenge.
9. **Verify on the real hostname**: certificate issued for both names, a lure
   page with Tigris images, Google **and** Apple sign-in (callback URLs are
   domain-based and unchanged — confirm neither is pinned to `fly.dev`), a
   moderation action, a background job running, `/robots.txt`, a sitemap, and
   two locales.
10. `systemctl start backup.service` and confirm the four new dumps land in
    `/opt/backups/postgres/`.

## Phase 5 — decommission and tidy

1. Keep the Fly machine **stopped but intact for a week**. Rollback is: DNS back
   to `66.241.124.31` / `2a09:8280:1::137:f6ff:0` and `fly machine start`. That
   is valid only until writes land on the new host — after that, rolling back
   loses them, so the week is a safety net for *outages*, not for *data*.
2. Then `fly apps destroy lurepedia` and destroy volume `vol_vlyzy0nlxjjkqng4`.
   **Leave the Fly org and the Tigris bucket alone** (Phase 0, decision 1).
3. Repo: delete `fly.toml`, drop the `sqlite3` gem, and rewrite `CLAUDE.md`'s
   Deployment section — Caddy + Compose on the shared host, shared PG, Tigris
   (currently unmentioned there), no volume, `deploy.sh`. Delete the
   now-false constraints: SQLite-can't-be-shared, one-machine-only,
   `min_machines_running`, the volume-is-the-database warning, and the
   root-vs-`rails` storage-permission trap, which was a Fly-volume problem and
   is gone with local blobs.
4. **Also fix Wunderkind** (separate, discovered here): its
   `config/deploy.yml` and the "Deployment is via Kamal" line in its `CLAUDE.md`
   describe infrastructure that does not exist — wrong proxy, wrong DB container
   name (`wunderkind-db` vs `postgres`), wrong architecture (`arm64` vs amd64),
   and a registry that is not used. Delete the file and correct the doc, or the
   next person deploys into a fiction.

## Risks, in the order they are likely to bite

1. **Unreset sequences** → PK collision on the first write after cutover.
   Phase 2 step 4 and Phase 4 step 5; verify by creating and destroying one row.
2. **Memory pressure.** Two Rails apps plus PG (1 GB `shared_buffers`) on 7.6 GB,
   with only 2 GB of swap, while Lurepedia's image jobs are the heaviest thing on
   the box. Mitigated by limits in Phase 0; watch during the first catalog import.
3. **Connection budget.** Four database pools × `RAILS_MAX_THREADS` × Puma
   workers, plus Solid Queue, against a shared `max_connections=100`. At
   `RAILS_MAX_THREADS=3` this is comfortable; raising threads or workers is what
   would break Wunderkind, not just Lurepedia.
4. **Type coercion** on 106k blob rows — booleans as `0/1`, datetimes as strings.
   Caught by the Phase 2 dry run, which is why the dry run exists.
5. **Collation reordering** in alphabetical lists (cosmetic, expected).
6. **Tigris coupling.** Compute leaves Fly, storage does not. Until Phase 0's
   decision is revisited, the site depends on a Fly-billed service.

## Verification checklist (run at Phase 2, Phase 3 and Phase 4)

- [ ] Row counts match: 71 / 2030 / 26516 / 4587 / 6 / 285 / 5 / 106098 / 106098 / 79885
- [ ] `reset_pk_sequence!` run for every table; create+destroy one record
- [ ] Booleans are `true/false`; datetimes UTC; `json` columns parse
- [ ] Lure page renders with Tigris images; a variant is generated on demand
- [ ] `LureFilter` search, the async combobox (`/options/*`), pagination
- [ ] Google and Apple sign-in
- [ ] Moderation queue actions; a Solid Queue job runs to completion
- [ ] `/up`, `/robots.txt`, sitemap, `/design-system`, a non-`en` locale
- [ ] HTTPS on apex and `www` (redirecting), HSTS present
- [ ] Nightly backup produced all four dumps
