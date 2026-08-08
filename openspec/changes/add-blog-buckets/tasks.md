## 1. Module extension

- [x] 1.1 Add optional `public_access_enabled` and `custom_domain` inputs to `modules/r2-bucket/variables.tf`, defaulting to disabled
- [x] 1.2 Add a count-guarded `cloudflare_r2_custom_domain` resource and its DNS record to `modules/r2-bucket/main.tf`, following the existing CORS and lifecycle guarding pattern
      — no separate `cloudflare_dns_record`: the R2 custom-domain binding creates the CNAME itself, and a second resource for the same name would fight it. Recorded in the module README.
- [x] 1.3 Surface the public hostname of any domain-bound bucket in `modules/r2-bucket/outputs.tf`
- [x] 1.4 Run `tofu plan` and confirm no change is proposed for `cgrs-images-prod` or `cgrs-documents-prod`
      — plan shows no action on any existing bucket, including `cgrs-ground-reports-prod`, after the origin-list refactor.
- [x] 1.5 Update `modules/r2-bucket/README.md` with the new inputs and their default-off behaviour

## 2. Bucket declarations

- [x] 2.1 Extract the web application origin list to a shared local, replacing the duplicated lists in the existing two bucket declarations
      — a root variable `web_app_origins` rather than a `locals` block, because tfvars cannot reference locals. A `cors_rules` entry that omits `allowed_origins` inherits it. Applied to all three existing buckets.
- [x] 2.2 Shape the declarations so a further community is an added entry rather than new resource work, and note this in the tfvars comments
- [x] 2.3 Declare `cgrs-blog-prod` in `environments/prod/prod.tfvars`: public access enabled, custom domain `content.cgrs.co.nz`, GET/HEAD CORS from the shared origin list, multipart-abort lifecycle rule
      — the declaration names the zone (`cgrs.co.nz`), not its id; `tofu/main.tf` resolves the id with a `data "cloudflare_zone"` lookup. The zone is read, never managed — it holds Vercel, Clerk, and email records this estate does not own, so a `cloudflare_zone` resource would put the whole domain inside `tofu destroy`'s reach for the sake of one identifier.
- [x] 2.4 Declare `cgrs-blog-src-prod`: private, no CORS, multipart-abort lifecycle rule
- [x] 2.5 Confirm both buckets and the content hostname appear in `tofu/outputs.tf`

## 3. Apply and verify

Applied 2026-08-08 after `cgrs-iac-access` gained a second permission policy scoped to
`cgrs.co.nz` (DNS:Edit, Zone:Read). The zone lookup resolves on the data source's `.id`
attribute — the open question from §2 is settled.

- [x] 3.1 Apply and confirm both buckets, the custom domain binding, the DNS record, CORS, and both lifecycle rules were created
      — binding reports `ownership: active`; DNS resolves to Cloudflare proxy addresses. The CNAME was created by the binding, confirming no `cloudflare_dns_record` is needed. CORS on `cgrs-blog-prod` carries the five shared origins with GET/HEAD; `cgrs-blog-src-prod` has none. Both buckets carry the 86400s multipart-abort rule.
- [x] 3.2 Confirm `content.cgrs.co.nz` resolves and serves a hand-placed object anonymously
      — `HTTP/2 200`, `server: cloudflare`, and the `cache-control: public, max-age=60` set at write time was preserved, which is the header behaviour the publish pipeline depends on.
- [x] 3.3 Confirm an anonymous request against `cgrs-blog-src-prod` is refused
      — no custom domain, managed r2.dev domain disabled (`401`), unauthenticated S3 GET rejected. There is no hostname that serves it.
- [x] 3.4 Confirm a direct browser PUT against the public bucket is not permitted by CORS
      — `PUT` preflight from `https://cgrs.co.nz` returns `403`; the same preflight for `GET` returns `204` with `access-control-allow-methods: GET, HEAD`. An unauthenticated `PUT` is `401` regardless.

Both verification objects were deleted afterwards; both buckets are empty.

## 4. Credentials and documentation

- [x] 4.1 Create an R2 API token in the Cloudflare dashboard scoped to both new buckets
      — `cgrs-blog-r2`, Object Read & Write on `cgrs-blog-prod` and `cgrs-blog-src-prod`. Scoping verified rather than assumed: put/get/delete succeed on both blog buckets, while write **and** list are `AccessDenied` on `cgrs-documents-prod`, `cgrs-images-prod`, and `cgrs-ground-reports-prod`. A leak of these keys cannot reach the society's financial records.
- [x] 4.2 Store its keys as `cgrs-api` secrets and record the secret names
      — `BLOG_ACCESS_KEY_ID` and `BLOG_SECRET_ACCESS_KEY` in the `TF_VAR_cloud_run_secret_env_vars` map, alongside a generated `BLOG_REVALIDATE_SECRET`. Live on revision `cgrs-api-00219-9tt`. The non-secret `BLOG_CONTENT_DOMAIN` and `BLOG_REVALIDATE_URL` are in `tofu/main.tf` `env_vars`.
- [ ] 4.3 Confirm no R2 access key or secret appears in OpenTofu state
      — **this requirement is already false today.** `R2_ACCESS_KEY_ID` and `R2_SECRET_ACCESS_KEY` are present in prod state, because the estate injects them through `TF_VAR_cloud_run_secret_env_vars` into the Cloud Run service. Following the same pattern for the blog token puts `BLOG_*` keys in state too. Tofu manages no token *resource*, which is the part that holds. Needs a decision: relax the scenario to "no token is managed by OpenTofu", or move Cloud Run secrets to Secret Manager references.
- [x] 4.4 Update `environments/prod/README.md` with the token, the secret names, and an explicit statement that `cgrs-blog-prod` is world-readable by design and must never receive unpublished content
- [x] 4.5 Hand the content hostname and both bucket names to the `r2-published-blog` change as per-community application configuration
      — `app/config.py` already defaults `blog_public_bucket_name` / `blog_private_bucket_name` to these names; `BLOG_CONTENT_DOMAIN` is set from `.envrc` per the README.
- [x] 4.6 Record in the environment README how a second community would be provisioned, so the per-tenant cost is known rather than discovered
