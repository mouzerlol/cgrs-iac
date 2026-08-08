# Prod Environment

This directory contains the configuration for the production environment.

## Files

- `.envrc` - direnv configuration (loads `.env.prod`)
- `prod.tfvars` - OpenTofu variables
- `prod.tfbackend` - OpenTofu backend configuration

## Usage

```bash
# With direnv (auto-loads .envrc)
cd tofu
tofu init -backend-config=../prod/prod.tfbackend
tofu plan -var-file=../prod/prod.tfvars

# Or use Makefile
make init ENV=prod
make plan ENV=prod
make apply ENV=prod
```

## State

State is stored in R2 at `prod/cgrs.tfstate`.

## Cloud Run keep-warm

`cgrs-api` is kept responsive during NZ waking hours by *periodic traffic*, not by paid idle
instances. A single `google_cloud_scheduler_job` (`cgrs-api-keep-warm`, in the
`cloud-run-keep-warm` module) issues an unauthenticated `GET /health` against the service:

| Setting | Value |
|---|---|
| Schedule | `*/5 6-22 * * *` (every 5 min) |
| Time zone | `Pacific/Auckland` (DST-aware) |
| Target | `<service_url>/health` — DB-free, returns in ~3 ms |
| `attempt_deadline` | `30s` |
| `retry_config.retry_count` | `1` |

- **Warm window:** 06:00–22:59 `Pacific/Auckland` — pinged, so an instance normally stays resident
- **Cold window:** 23:00–05:59 `Pacific/Auckland` — no pings, service genuinely scales to zero

Under request-based billing (`cpu_idle = true`) an instance is charged only while it processes a
request, plus start and shutdown. A resident-but-idle instance at `min_instance_count = 0` is **not**
billed, and Cloud Run keeps instances idle for up to ~15 minutes after a request. A 5-minute ping
against that retention budget is a 3× margin.

### `min_instance_count = 0` is a hard invariant

`cloud_run_min_instances = 0` in `prod.tfvars`, and `tofu/variables.tf` validates that it is `0`.
Nothing mutates the field at runtime any more, so the `ignore_changes` on
`template[0].scaling[0].min_instance_count` has been **removed** from `modules/cloud-run/main.tf` —
Tofu owns the field again and any accidental re-introduction of a non-zero value shows up as drift in
`make plan`.

### Cost basis (measured, 2026-07-28, ~44 h post-cutover)

- `billable_instance_time` fell from **61,300 s/day → 297 s/day**, a **99.5% reduction**.
- Monthly projection: **~12,150 vCPU-s = 6.8%** of the 180,000 vCPU-s free allowance
  (and ~4,620 GiB-s = 1.3% of 360,000). Previously 10.6× and 2.6× *over*.
- Cloud Run cost: **$0/month**, down from ~$10.40 gross / ~$5.20 net.
- Cloud Scheduler bills per job, not per execution, so the 5-minute cadence is free.

### Best-effort, not a guarantee

Cloud Run's idle-instance retention is documented as "might", not "will". Accepted and not mitigated:

- Cloud Run may still evict the resident instance between pings.
- A request landing on a scale-from-zero still pays the full container startup.
- A burst needing a second instance (`max_instances = 2`) pays a cold start for it — `min_instance_count = 1`
  never covered the second instance either.
- The Neon Free autosuspend wake (~300–800 ms) is untouched. Min-instances never addressed it.

Measured after cutover: 5–6 startups/day against ~204 pings/day, **zero startups inside the warm
window**, mid-window request median 31 ms. Every ping returned 200; zero failures.

### Operating

```bash
make scheduler-trigger-ping ENV=prod     # fire the keep-warm ping now (expect HTTP 200)
make cloud-run-min-instances ENV=prod    # drift check — should ALWAYS read 0
make cloud-run-force-warm ENV=prod       # EMERGENCY: pin min_instances=1 (billed! revert)
make cloud-run-unpin ENV=prod            # revert force-warm back to 0
```

`scheduler-trigger-ping` replaces the retired `scheduler-trigger-up` / `scheduler-trigger-down`
targets, which PATCHed `min_instance_count` on a schedule.

### Identifying pings in logs

```
httpRequest.userAgent="Google-Cloud-Scheduler" AND httpRequest.requestUrl:"/health"
```

The `userAgent` clause alone also matches the email-reconcile job, hence the path clause.

Two gotchas worth knowing before you try something "cleaner":

- The job sends `X-CGRS-Keepalive: 1` and the header **is** delivered to the app, but Cloud Run
  request logs carry only a fixed set of `httpRequest` fields — **the header does not appear in
  Cloud Run logs** and cannot be filtered on there. Only the application could log it.
- A **custom `User-Agent` cannot be used**. Cloud Scheduler overrides it with
  `Google-Cloud-Scheduler`, and because the API does not echo the configured value back, setting one
  produced a perpetual OpenTofu diff (every plan showed the job as needing an update). Removed in
  commit `55a8cea`.

### Disabling during an incident

```bash
# In environments/prod/prod.tfvars
cloud_run_scheduler_enabled = false
make apply ENV=prod
```

This destroys the keep-warm ping job. `min_instance_count` stays `0`, so the service will simply be
cold until first request. To force warmth immediately without IaC, use `make cloud-run-force-warm`
(this is also the ping-to-warm rollback) — it is billed idle time and leaves the free tier, so revert
with `make cloud-run-unpin`.

## Billing export (BigQuery)

Per-SKU spend is exported to BigQuery so a cost regression is *queryable* rather than reconstructed
from Cloud Monitoring usage metrics. `modules/billing-export` creates the destination dataset:

| Item | Value |
|---|---|
| Dataset | `billing_export` (`billing_export_dataset_id` in `prod.tfvars`) |
| Project | `cgrs-492610` |
| Location | `australia-southeast1` (`gcp_region`) |
| Gate | `billing_export_enabled = true` in `prod.tfvars` |
| Export type | **Standard usage cost** (not Detailed) |
| Billing account | `01025D-63750F-AAE0CD` |

Standard, not Detailed: Standard attributes spend to a SKU, which is the whole requirement, while
Detailed emits per-resource rows that grow substantially faster. Cost is ~$0 — the export is
single-digit MB/month against 10 GiB/month free active storage and 1 TiB/month free query.

The dataset has no table or partition expiry, and `delete_contents_on_destroy = false`, so a
`tofu destroy` on a populated export fails loudly rather than deleting billing history.

### ⚠️ `make apply` alone does NOT finish this

Google provides **no Terraform resource, no gcloud command and no stable API** for enabling Cloud
Billing export to BigQuery — linking a billing account to a dataset is Console-only (see
[terraform-provider-google#4848](https://github.com/hashicorp/terraform-provider-google/issues/4848)).
Tofu creates the *receiver* only. **After `make apply ENV=prod` the dataset exists and stays
permanently empty until a human does the one-time link in the Console.** A fresh environment is
therefore not reproducible from `make apply` alone. If the verification query below returns no rows,
this manual step is the missing piece — not the module.

### One-time Console linking steps

1. Console → **Billing** → select billing account `01025D-63750F-AAE0CD`.
2. **Billing export** → **BigQuery export** tab.
3. Under **Standard usage cost**, click **Edit settings**.
4. Project: `cgrs-492610`. Dataset: `billing_export`.
5. **Save**.
6. **Wait ~24 h.** The export backfills asynchronously; the table
   `gcp_billing_export_v1_01025D_63750F_AAE0CD` does not exist until the first write lands.

### Verification query (per-SKU cost)

```sql
SELECT
  service.description AS service,
  sku.description     AS sku,
  ROUND(SUM(cost), 4) AS cost_usd,
  ROUND(SUM((SELECT SUM(c.amount) FROM UNNEST(credits) c)), 4) AS credits_usd
FROM `cgrs-492610.billing_export.gcp_billing_export_v1_01025D_63750F_AAE0CD`
WHERE usage_start_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
GROUP BY service, sku
HAVING cost_usd > 0
ORDER BY cost_usd DESC
```

Run it in the BigQuery Console, or `bq query --use_legacy_sql=false '<query>'`. Rows returning at all
confirms the link works. For this change specifically, the `Services Min Instance CPU Tier 2` and
`Services Min Instance Memory Tier 2` SKUs should be absent (or zero) after 2026-07-26.

Verification gate task 5.5 of the `ping-to-warm-cloud-run` change had to **substitute** Cloud
Monitoring evidence (`billable_instance_time` falling to 297 s/day) because this export did not exist
at cutover. Building it and completing the Console link closes that gap, so the next cost regression
can be attributed from billing data directly.

## R2 buckets

Buckets are declared in `prod.tfvars` under `r2_buckets` and provisioned by `modules/r2-bucket` (bucket + optional CORS + optional lifecycle + optional public access and custom domain).

- **`cgrs-images-prod`** — website images. CORS allows browser presigned `PUT` (direct upload).
- **`cgrs-documents-prod`** — society governance documents (minutes, agendas, financial records). Uploads are proxied server-side through the API, so CORS is **GET/HEAD only** (no browser PUT). A lifecycle rule aborts incomplete multipart uploads after 1 day.
- **`cgrs-ground-reports-prod`** — ground-report images (location-tagged photos of the development). Uploads are proxied server-side; the member reel loads images via presigned GET, so CORS is **GET/HEAD only**. Unlike the documents bucket, it reuses the **shared account** R2 token (no dedicated token) — see below. (A 180-day object-expiration lifecycle is intentionally out of scope for now; the API's member query already excludes >180-day reports.)
- **`cgrs-blog-prod`** — ⚠️ **world-readable by design.** Published blog artifacts only: the `index.json` manifest, per-post body documents, and published imagery. Bound to `content.cgrs.co.nz`, which is what makes it public and puts it behind Cloudflare's edge cache. Public pages fetch straight from this hostname, so the reading path touches neither Cloud Run nor Neon. **Nothing unpublished may ever be written here** — R2 public access is bucket-wide, so an "unlisted" key would still be served to anyone who asked for it. Drafts belong in `cgrs-blog-src-prod`. CORS is GET/HEAD only; every write is server-side through the API. Multipart fragments abort after 1 day.
- **`cgrs-blog-src-prod`** — private companion to the above: source markdown, revision archives, and unpublished assets. No custom domain, no public access, no CORS (no browser addresses it). Multipart fragments abort after 1 day.

**CORS origins are declared once.** `web_app_origins` in `prod.tfvars` holds the list; a `cors_rules` entry that omits `allowed_origins` inherits it. Changing the deployed origins is one edit, not one per bucket.

### Blog bucket credentials (out-of-band, not Terraform-managed)

The blog buckets are accessed by `cgrs-api` using a **dedicated** R2 API token scoped to the pair, so neither the images nor the documents token can reach them.

1. In the Cloudflare dashboard, create an **R2 API token** with **Object Read & Write** applied to `cgrs-blog-prod` **and** `cgrs-blog-src-prod` only (both buckets must already exist — apply first). It must be an R2 token, not a generic account token: the API signs S3 requests, so what you need off the confirmation screen is the **Access Key ID** and **Secret Access Key**, not the bearer token value. They are shown once.
2. Add the two keys, plus the shared revalidation secret, to the `TF_VAR_cloud_run_secret_env_vars` JSON map in `environments/prod/.envrc`:
   - `"BLOG_ACCESS_KEY_ID": "<access key id>"`
   - `"BLOG_SECRET_ACCESS_KEY": "<secret access key>"`
   - `"BLOG_REVALIDATE_SECRET": "<shared with the frontend>"`
3. Re-run `make apply ENV=prod` so the Cloud Run service picks up the new secret env vars.
4. Set `BLOG_REVALIDATE_SECRET` to the **same value** in Vercel, and `BLOG_CONTENT_ORIGIN=https://content.cgrs.co.nz` alongside it.

Notes:
- `BLOG_CONTENT_DOMAIN` and `BLOG_REVALIDATE_URL` are **not secret** and are set in `tofu/main.tf` `env_vars` — no `.envrc` change needed for them.
- `BLOG_REVALIDATE_SECRET` must match the frontend's exactly, or the publish signal is refused and a new post appears only when the manifest's 60-second window lapses. Publishing still succeeds; a failed signal never fails a publish. A leak of it permits cache invalidation and nothing else.
- `BLOG_PUBLIC_BUCKET_NAME` and `BLOG_PRIVATE_BUCKET_NAME` default to these bucket names in `app/config.py`; no change needed unless they are renamed.
- `R2_ACCOUNT_ID` is **shared** — the blog client reuses the account id and account-level S3 endpoint; only the keys and target buckets differ.
- To prove the token is actually scoped, try a write against `cgrs-documents-prod` with it. It must fail. A token that succeeds there is account-scoped and defeats the point of a dedicated one.

### Custom domains need a token with zone rights

A bucket declares its `custom_domain` by hostname and **zone name**, not zone id — `tofu/main.tf` resolves the id with a `data "cloudflare_zone"` lookup, so no opaque identifier lives in configuration.

The zone itself is deliberately **not** a Terraform resource. It holds records this estate does not own (Vercel, Clerk, email), so managing it would put the whole domain inside `tofu destroy`'s blast radius to gain one identifier.

Both the lookup and the binding need zone permissions the estate's token did not originally carry. Without them `tofu plan` fails at the lookup with `failed to find exactly one result … 0 found` — not a forbidden response, an empty one: the token has no zone resources at all.

This is a **permission change to the existing `cgrs-iac-access` token**, not a second token. It must carry all four:

| Scope | Permission | Why |
| --- | --- | --- |
| Account | Workers R2 Storage → Edit | buckets, CORS, lifecycle, custom-domain binding |
| Account | Turnstile → Edit | `module.turnstile` widget, already managed here |
| Zone | Zone → Read | the `data "cloudflare_zone"` lookup |
| Zone | DNS → Edit | the CNAME the binding creates |

**Manage Account → Account API Tokens → `cgrs-iac-access` → Edit.** Add the two zone permissions and set Zone Resources to *Specific zone → `cgrs.co.nz`*. Editing permissions does not rotate the secret, so `.envrc` needs no change — `CLOUDFLARE_API_TOKEN` and `TF_VAR_cloudflare_api_token` keep their current (identical) value.

To confirm which token `.envrc` holds without printing it:

```bash
set -a && . environments/prod/.envrc && set +a
curl -s "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/tokens/verify" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN"
```

It returns the token's id and status. As of 2026-08-08 that is `091215223cfc30379d0a9808344f98eb`.

The R2 **S3** credentials used for the state backend (`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`) are a separate thing and are unaffected.

### Provisioning a second community

Community isolation for blog content is **per bucket, not per key prefix**, so the whole per-tenant infrastructure cost is known up front:

1. Two more entries in `r2_buckets` — `<community>-blog-prod` with a `custom_domain` on its own hostname, and a private `<community>-blog-src-prod`. No new resource types, no module changes. If the hostname sits in a different zone, the zone lookup picks it up automatically and the API token's Zone Resources must be widened to include it.
2. One more R2 API token scoped to that pair.
3. One more entry in the API's `BLOG_COMMUNITIES` JSON map, keyed by community slug, carrying that community's buckets, content domain, revalidation target, and keys.

Nothing else. Cross-tenant reads are impossible by construction: a key that is not in a community's bucket is simply not found on its content domain, regardless of how the application builds keys.

### Ground-reports bucket credentials

The ground-reports bucket reuses the **shared account** R2 token (`R2_ACCESS_KEY_ID` / `R2_SECRET_ACCESS_KEY`) — no dedicated token. This requires that token to be **account-scoped** (able to write any bucket). If it is instead locked to specific buckets, either add `cgrs-ground-reports-prod` to its allow-list or set dedicated `R2_GROUND_REPORTS_ACCESS_KEY_ID` / `R2_GROUND_REPORTS_SECRET_ACCESS_KEY` secrets (the API prefers these when present, else falls back to the shared token). `R2_GROUND_REPORTS_BUCKET_NAME` is non-secret and set in `tofu/main.tf` `env_vars`.

### Documents bucket credentials (out-of-band, not Terraform-managed)

The documents bucket is accessed by `cgrs-api` using a **dedicated** R2 API token, separate from the images token, so an images-token leak cannot reach financial documents. Terraform does not manage R2 API tokens.

1. In the Cloudflare dashboard, create an R2 API token scoped to **Object Read & Write** on `cgrs-documents-prod` **only** (the bucket must already exist — apply this change first).
2. Add the two keys to the `TF_VAR_cloud_run_secret_env_vars` JSON map in `environments/prod/.envrc` (the same map that already holds `R2_ACCOUNT_ID` / `R2_ACCESS_KEY_ID` / `R2_SECRET_ACCESS_KEY`):
   - `"R2_DOCUMENTS_ACCESS_KEY_ID": "<token access key id>"`
   - `"R2_DOCUMENTS_SECRET_ACCESS_KEY": "<token secret>"`
3. Re-run `make apply ENV=prod` so the Cloud Run service picks up the new secret env vars.

Notes:
- `R2_DOCUMENTS_BUCKET_NAME` is non-secret and is set in `tofu/main.tf` `env_vars` (no `.envrc` change needed).
- `R2_ACCOUNT_ID` is **shared** — the documents client reuses the existing account id and the account-level S3 endpoint (`<account_id>.r2.cloudflarestorage.com`); only the access/secret keys and target bucket differ from the images bucket.

## Warning

Production changes should be reviewed carefully. CI/CD workflow requires approval before applying.
