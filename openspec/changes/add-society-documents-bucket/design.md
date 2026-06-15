## Context

The IaC stack is OpenTofu with a reusable `modules/r2-bucket` module driven by a `r2_buckets` list variable in `environments/prod/prod.tfvars`. Adding a bucket is normally just a new list entry; `tofu/main.tf` already does `for_each` over the list, and `tofu/outputs.tf` already iterates `module.r2_buckets`. The module today supports the bucket itself plus optional `cloudflare_r2_bucket_cors`.

The new bucket stores sensitive society governance documents. The app side (`add-society-documents` in the root openspec) proxies uploads through the API and serves downloads via presigned GET, which shapes the CORS decision here.

The Cloudflare provider (5.x) exposes `cloudflare_r2_bucket`, `cloudflare_r2_bucket_cors`, and `cloudflare_r2_bucket_lifecycle` — but **no versioning resource or attribute**. Versioning is therefore out of scope (the app uses in-place overwrite; see the app-side design).

## Goals / Non-Goals

**Goals:**
- A dedicated, IaC-managed bucket for society documents, isolated from the images bucket.
- CORS scoped to exactly what the app needs (GET/HEAD), no broader.
- Credential isolation: a bucket-scoped token, so an images-token leak can't reach financial documents.

**Non-Goals:**
- Terraform-managing the R2 API token (kept dashboard-created, matching current practice).
- Bucket versioning (not provider-supported; app uses in-place overwrite).
- Any change to `cgrs-images-prod` or `cgrs-state-storage`.

## Decisions

### Reuse the `r2_buckets` list, not a bespoke module
The bucket is one more entry in `r2_buckets`. This keeps a single code path for all R2 buckets and makes the diff a few lines of tfvars plus the lifecycle addition.

### CORS is GET/HEAD only
Because the app proxies uploads (browser → API → R2), the browser never PUTs directly to R2, so no PUT/OPTIONS CORS rule is required — unlike `cgrs-images-prod`, which allows PUT for presigned browser uploads. Downloads use presigned GET, so GET/HEAD for the web-app origins is sufficient. Narrower CORS = smaller attack surface on a sensitive bucket.

### Lifecycle: abort stale multipart uploads after 1 day
Proxied uploads can leave orphaned multipart fragments on failure. A `cloudflare_r2_bucket_lifecycle` rule (`abort_multipart_uploads_transition`, max_age 1 day) reclaims them. Added to `modules/r2-bucket` behind an optional `lifecycle_rules` variable (count-guarded) so it is a no-op for existing buckets.

### Dedicated token, created out-of-band
A new R2 API token scoped to `cgrs-documents-prod` is created in the Cloudflare dashboard. Its keys are stored as `cgrs-api` secrets (`R2_DOCUMENTS_ACCESS_KEY_ID` / `R2_DOCUMENTS_SECRET_ACCESS_KEY`). The R2 S3 endpoint is account-level and unchanged (`<account_id>.r2.cloudflarestorage.com`); only the access/secret keys and target bucket differ. Terraform-managing the token (`cloudflare_api_token` with R2 permission groups) is possible but deferred — it would put a long-lived secret into tofu state, and the stack does not manage tokens today.

## Risks / Trade-offs

- **Drift between CORS origins and the app's deployed origins** would silently break presigned-GET fetches. Mitigation: reuse the same origin list as `cgrs-images-prod` (single source to keep in sync), documented in the README.
- **Out-of-band token** means a manual provisioning step that isn't captured in `tofu plan`. Mitigation: README runbook listing exact token scope + secret names.
- **Lifecycle variable touches the shared module.** Mitigation: count-guarded and defaulted to empty, so `cgrs-images-prod` is unaffected and produces no plan diff.
