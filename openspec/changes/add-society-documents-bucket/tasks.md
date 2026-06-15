## 1. Module: optional lifecycle rules

- [x] 1.1 Add a `lifecycle_rules` variable to `modules/r2-bucket/variables.tf` (list of objects: `id`, `prefix`, `enabled`, optional `abort_multipart_max_age_days`), defaulting to `[]`
- [x] 1.2 Add a count-guarded `cloudflare_r2_bucket_lifecycle` resource to `modules/r2-bucket/main.tf` (created only when `length(var.lifecycle_rules) > 0`), with `depends_on = [cloudflare_r2_bucket.this]`. Also wired `lifecycle_rules` through `tofu/variables.tf` (r2_buckets type) and `tofu/main.tf` (module call). `tofu validate` passes.
- [x] 1.3 Confirmed by inspection: lifecycle resource is `count`-guarded and the module call passes `try(each.value.lifecycle_rules, [])`, so `cgrs-images-prod` (no lifecycle_rules) → `[]` → count 0 → no resource → no diff. (Live `make plan` confirmation is task 4.1.)

## 2. Provision the documents bucket

- [x] 2.1 Append `cgrs-documents-prod` to `r2_buckets` in `environments/prod/prod.tfvars` with `description` and GET/HEAD-only `cors_rules` (origins mirroring `cgrs-images-prod`: localhost:3000, 127.0.0.1:3000, cgrs.co.nz, www.cgrs.co.nz)
- [x] 2.2 Add a `lifecycle_rules` entry aborting incomplete multipart uploads after 1 day (empty prefix, enabled)
- [x] 2.3 Confirmed: `tofu/outputs.tf` `r2_buckets` output iterates `module.r2_buckets`, so the new bucket surfaces automatically. No explicit output added.

## 3. Documentation (runbook)

- [x] 3.1 Document the token scope, secret names, and the CORS-origin sync note in `environments/prod/README.md`

## 4. Plan & apply — creates the bucket

> `tofu apply` uses Terraform's own `CLOUDFLARE_API_TOKEN` provider credential to create the bucket. It does NOT require the bucket-scoped documents token (which doesn't exist yet). Do this BEFORE creating the token.

- [x] 4.1 `make plan` — diff limited to bucket + CORS + lifecycle; no changes to `cgrs-images-prod` (operator-run)
- [x] 4.2 `make apply` — `cgrs-documents-prod` now exists (confirmed by operator)
- [x] 4.3 Verified in dashboard: CORS = GET/HEAD for the expected origins; lifecycle rule `abort-incomplete-multipart-1d` enabled

> Note: `R2_DOCUMENTS_BUCKET_NAME = "cgrs-documents-prod"` was added to `tofu/main.tf` `env_vars` AFTER this apply, so a follow-up `make apply` (task 5.3) is needed to push it + the new secrets to Cloud Run.

## 5. Out-of-band credentials — requires the bucket to exist first

> A bucket-scoped R2 API token can only be created against an existing bucket, so this section runs AFTER `make apply` (section 4).

- [ ] 5.1 Create an R2 API token in the Cloudflare dashboard scoped to **Object Read & Write** on `cgrs-documents-prod` only
- [ ] 5.2 Add its keys to the `TF_VAR_cloud_run_secret_env_vars` JSON map in `environments/prod/.envrc` (`R2_DOCUMENTS_ACCESS_KEY_ID`, `R2_DOCUMENTS_SECRET_ACCESS_KEY`); `R2_ACCOUNT_ID` is already present and shared
- [ ] 5.3 `make apply ENV=prod` again so Cloud Run picks up `R2_DOCUMENTS_BUCKET_NAME` + the new secret env vars; then smoke-test a presigned GET against `cgrs-documents-prod`
