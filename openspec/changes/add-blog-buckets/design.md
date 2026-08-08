## Context

Two R2 buckets exist in production, both private: `cgrs-images-prod` for user uploads and `cgrs-documents-prod` for society governance documents. Both are reached exclusively by `cgrs-api` using S3 credentials from a dashboard-created token, and `modules/r2-bucket` provisions them with optional CORS and lifecycle configuration, count-guarded so an omitted block creates no resource.

The blog change in the root openspec inverts that access model for one bucket. Public blog pages must render without calling Cloud Run or waking Neon, which means the browser and the Vercel build read published artifacts directly. That requires a bucket the public internet can read, addressed by a hostname the application can hard-code — neither of which the estate has needed before.

The Cloudflare provider is pinned at `~> 5.0`, which exposes custom-domain binding as a first-class resource.

## Goals / Non-Goals

**Goals:**

- Provision a publicly readable bucket for published blog artifacts, on a stable hostname under `cgrs.co.nz`.
- Provision a private companion bucket so unpublished content has somewhere to live that is not the public one.
- Extend the shared module without changing the plan for any existing bucket.
- Keep credentials out of Terraform state, matching current practice.

**Non-Goals:**

- No cache-purge tooling or Cloudflare API token for purging. Published keys are content-hashed and immutable by design, so nothing is ever mutated in place.
- No cache-control configuration here. Headers are set per object by the API at write time, because they differ by object class — immutable for hashed keys, short-lived for the manifest.
- No bucket policy expressing "only these prefixes are public". R2 public access is bucket-wide; the separation is achieved with a second bucket, not with policy.
- No non-production environments. Prod is the only environment this estate provisions.

## Decisions

### Two buckets rather than prefix separation

**Chosen:** `cgrs-blog-prod` public, `cgrs-blog-src-prod` private.

**Alternative considered:** one bucket with working content under prefixes nobody links to. Rejected because R2 public access is bucket-wide — an unlisted prefix is still served to anyone who requests it. A draft would be genuinely fetchable, which is security by URL obscurity rather than by configuration.

**Consequence:** the API holds credentials for both and performs a copy at publish time. That copy is what makes "published" a real state transition rather than a flag.

### Custom domain rather than the managed r2.dev endpoint

**Chosen:** bind `content.cgrs.co.nz` with `cloudflare_r2_custom_domain` plus its DNS record.

**Alternative considered:** the account-specific managed domain. Rejected because it embeds the account identifier in every published URL and in application configuration, ties content addressing to an account rather than to the society, and is rate-limited in a way not intended for production traffic.

**Consequence:** published image URLs live under `content.cgrs.co.nz`, so the frontend's `remotePatterns` and CSP list a hostname the society controls and can move later.

### Module extension, count-guarded and defaulted off

**Chosen:** add optional `public_access_enabled` and `custom_domain` inputs to `modules/r2-bucket`, implemented the same way CORS and lifecycle already are — a resource with `count` derived from whether the input was supplied.

**Alternative considered:** a separate module for the public bucket. Rejected because it would duplicate bucket, CORS, and lifecycle handling for one differing property, and the two would drift.

**Verification:** the acceptance test for this decision is a plan against the existing buckets that proposes no change.

### Credentials stay out of Terraform

**Chosen:** a dashboard-created R2 API token scoped to both new buckets, keys stored as `cgrs-api` secrets.

**Rationale:** matches how the images and documents tokens are handled, and keeps secrets out of state. Not revisited here.

### CORS is GET/HEAD on the public bucket, absent on the private one

**Chosen:** the public bucket allows GET and HEAD from the web application origins; the private bucket declares no CORS.

**Rationale:** every write is server-side through the API, so no browser ever issues a PUT. No browser addresses the private bucket at all.

**Maintenance note:** the origin list is now duplicated across three bucket declarations. It is already duplicated across two, and the existing configuration flags this in a comment. Extracting it to a shared local is worth doing while adding the third.

## Risks / Trade-offs

- **A public bucket is genuinely public** → only rendered, publication-intended artifacts are ever written to it, and the private companion exists so nothing else has a reason to be. This must be stated in the environment README, not left as tribal knowledge.
- **Public access is bucket-wide, so a single mistaken write exposes content** → the application, not infrastructure, enforces which bucket receives what. Infrastructure's contribution is making the safe destination exist and documenting the posture.
- **Custom domain binding requires DNS that OpenTofu now owns** → keep the record adjacent to the binding in the module so they cannot drift apart, and confirm resolution as an explicit post-apply step.
- **Origin list duplicated across three buckets** → extract to a shared local while adding the third, so the next origin change is one edit.
- **Public reads bypass every application log** → traffic to published content is visible only in Cloudflare analytics. Accepted; the reading path having no origin server is the point.

## Migration Plan

1. Extend `modules/r2-bucket` with the optional inputs and confirm `tofu plan` proposes no change for the existing buckets.
2. Add both bucket declarations to `environments/prod/prod.tfvars` and apply.
3. Confirm DNS resolves and an object placed by hand is fetchable at `https://content.cgrs.co.nz/<key>`.
4. Create the bucket-scoped token in the dashboard and store its keys as `cgrs-api` secrets.
5. Update `environments/prod/README.md` with the token, the secret names, and the public-read posture.
6. Rollback is removing the two bucket declarations and reverting the module. No other bucket or service depends on them until the application change lands.

## Open Questions

- Whether `content.cgrs.co.nz` is the right hostname, or whether a name signalling public-by-design — `public.` or `cdn.` — would better resist someone treating it as general-purpose storage later.
- Whether the private bucket should carry a lifecycle rule expiring archived revisions after a retention period, or keep them indefinitely given their small size.
