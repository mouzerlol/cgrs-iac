## Why

The blog is moving off a JSON file bundled into the frontend and onto R2, so that a committee member can publish without a developer and without a deployment, and so that public blog pages stop depending on Cloud Run and Neon. The application-side data model, admin UI, and publish pipeline are covered by the `r2-published-blog` change in the root openspec; this change owns only the storage substrate.

That substrate is different in kind from the two buckets already provisioned. `cgrs-images-prod` and `cgrs-documents-prod` are both private, reached exclusively by the API with S3 credentials. The blog needs a bucket the public internet reads directly over a custom domain, so the reading path involves no credential, no API, and no origin server — plus a second private bucket for the working content that must never be public.

## What Changes

- **New public bucket** `cgrs-blog-prod`, holding only published artifacts for the `cgrs` community: the manifest, per-post body documents, and published imagery.
- **Isolation between communities is by bucket, not by key prefix.** The application database is multi-tenant; each community gets its own bucket pair and content domain, so a cross-tenant read is impossible regardless of application behaviour. Only `cgrs` is provisioned here, and the declarations are shaped so a second community is an added entry rather than bespoke work.
- **Custom domain** `content.cgrs.co.nz` bound to that bucket via `cloudflare_r2_custom_domain`, with the DNS record it requires. This is the first bucket in the estate exposed to public reads, and the first to need a domain binding — the `modules/r2-bucket` module gains optional public-access and custom-domain support, count-guarded so existing buckets are untouched.
- **New private bucket** `cgrs-blog-src-prod`, holding source markdown, revision archives, and unpublished assets. Never publicly readable; reached only by the API with S3 credentials.
- **CORS on the public bucket**: GET and HEAD only. Objects are written server-side by the API, never by a browser.
- **Lifecycle rules**: abort incomplete multipart uploads after 1 day on both buckets, matching existing practice.
- **No cache-purge credential.** Published object keys embed a content hash and are served immutable, so no object is ever mutated in place and no Cloudflare cache purge is required. Cache-control headers are set per object by the API at write time, not by infrastructure. Nothing here needs a Cloudflare API token beyond what OpenTofu already uses.
- **Credentials remain out of Terraform.** A bucket-scoped R2 API token covering both new buckets is created in the Cloudflare dashboard and its keys stored as `cgrs-api` secrets, matching how the images and documents tokens are handled today.

## Capabilities

### New Capabilities

- `blog-content-buckets`: a publicly readable R2 bucket on a custom domain serving published blog artifacts, paired with a private bucket for source and unpublished content, IaC-managed for creation, public access, domain binding, CORS, and lifecycle, with credentials supplied out-of-band by a dashboard-created, bucket-scoped token.

### Modified Capabilities

_None — `openspec/specs/` is empty, as `add-society-documents-bucket` has not been archived. The shared `modules/r2-bucket` module gains optional public-access and custom-domain variables that default off, so no existing bucket's provisioning changes._

## Impact

- **Code**:
  - `modules/r2-bucket/{main.tf,variables.tf,outputs.tf}` — optional `public_access_enabled` and `custom_domain` variables; count-guarded `cloudflare_r2_custom_domain` resource; outputs surfacing the public hostname.
  - `environments/prod/prod.tfvars` — append `cgrs-blog-prod` (public, custom domain, GET/HEAD CORS) and `cgrs-blog-src-prod` (private, no CORS) to `r2_buckets`.
  - `tofu/outputs.tf` — confirm both buckets and the content hostname surface.
  - `environments/prod/README.md` — document the token, which secrets carry its keys, and the deliberate public-read posture of the blog bucket.
- **Cloudflare resources created**: 2 R2 buckets, 1 custom domain binding, 1 DNS record, 1 CORS configuration, 2 lifecycle configurations.
- **Out-of-band**: 1 R2 API token scoped to both new buckets; keys stored as `cgrs-api` secrets.
- **Security posture**: `cgrs-blog-prod` is deliberately world-readable. Anything not intended for publication must never be written to it — that separation is enforced by the application, and the private companion bucket exists so it has somewhere else to go.
- **Cost**: R2 storage plus Class A/B operations. Public reads are served from Cloudflare's edge with no egress fee. Negligible at expected volumes.
- **No breaking changes.** `cgrs-images-prod` and `cgrs-documents-prod` are untouched; the new module variables default off.
