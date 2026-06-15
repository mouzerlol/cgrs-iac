## Why

CGRS needs a home for the society's own governance documents — meeting minutes, agendas, and financial records. Today the only R2 buckets are `cgrs-images-prod` (user-uploaded images) and `cgrs-state-storage`. Mixing sensitive financial documents into the images bucket would share a blast radius and a single credential with public-facing image uploads.

This change provisions a dedicated, IaC-managed R2 bucket for Society Documents, with credentials isolated from the images bucket so a leak of the images token cannot reach financial records. The app-side API, data model, and admin page are covered by the `add-society-documents` change in the root openspec; this change owns only the storage substrate.

## What Changes

- **New bucket** `cgrs-documents-prod`, declared as a second entry in the existing `r2_buckets` list in `environments/prod/prod.tfvars` (reuses the `modules/r2-bucket` module — no module change required).
- **CORS = GET/HEAD only.** Uploads are proxied through the API (server-side `put_object`), so the browser never issues a direct PUT to R2 — no PUT CORS rule is needed. GET/HEAD covers presigned-GET downloads. Origins mirror the web-app origin list used by `cgrs-images-prod`.
- **Lifecycle rule** via a new `cloudflare_r2_bucket_lifecycle` resource added to `modules/r2-bucket`: abort incomplete multipart uploads after 1 day (cheap hygiene; gated behind an optional variable so existing buckets are unaffected).
- **Outputs** extended so the new bucket appears in `tofu/outputs.tf` `r2_buckets`.
- **Credentials are NOT Terraform-managed.** A dedicated R2 API token scoped to `cgrs-documents-prod` is created in the Cloudflare dashboard; its access key id / secret are stored as `cgrs-api` secrets. This matches current practice (the images token is also dashboard-created). Documented in the change README and the environment README.

## Capabilities

### New Capabilities

- `society-documents-bucket`: a dedicated R2 bucket for society governance documents, IaC-managed for creation + CORS + lifecycle, with credentials supplied out-of-band by a dashboard-created, bucket-scoped token.

### Modified Capabilities

_None — there are no existing specs in `openspec/specs/` to modify._

## Impact

- **Code**:
  - `environments/prod/prod.tfvars` — append `cgrs-documents-prod` to `r2_buckets` with GET/HEAD CORS rules.
  - `modules/r2-bucket/{main.tf,variables.tf}` — add an optional `lifecycle_rules` variable + `cloudflare_r2_bucket_lifecycle` resource (count-guarded; default no-op).
  - `tofu/outputs.tf` — surface the new bucket (already iterates `module.r2_buckets`, so it appears automatically; confirm).
  - `environments/prod/README.md` — document the dedicated token + which secrets carry its keys.
- **Cloudflare resources created**: 1 R2 bucket, 1 CORS configuration, 1 lifecycle configuration.
- **Out-of-band**: 1 R2 API token (dashboard), scoped to the documents bucket; keys stored as `cgrs-api` secrets (`R2_DOCUMENTS_ACCESS_KEY_ID`, `R2_DOCUMENTS_SECRET_ACCESS_KEY`).
- **Cost**: R2 storage + Class A/B ops only; no egress fees. Negligible at expected document volumes.
- **No breaking changes.** The existing `cgrs-images-prod` bucket and its CORS are untouched; the lifecycle variable defaults off for it.
