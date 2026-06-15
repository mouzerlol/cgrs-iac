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

## Cloud Run scheduled scaling

`cgrs-api` is kept warm (`min_instance_count = 1`) during NZ waking hours and scaled to zero overnight, via two `google_cloud_scheduler_job` resources in the `cloud-run-scheduler` module:

- **Warm window:** 06:00–22:59 `Pacific/Auckland` (DST-aware)
- **Cold window:** 23:00–05:59 `Pacific/Auckland` (cold starts accepted)

The live `min_instance_count` is owned by Cloud Scheduler at runtime. Tofu does not reconcile drift on this field (`ignore_changes` in `modules/cloud-run/main.tf`).

### Operating

```bash
make scheduler-trigger-up ENV=prod      # force warm now (min=1)
make scheduler-trigger-down ENV=prod    # force cold now (min=0)
make cloud-run-min-instances ENV=prod   # show live min_instance_count
```

### Disabling during an incident

```bash
# In environments/prod/prod.tfvars
cloud_run_scheduler_enabled = false
make apply ENV=prod
```

This destroys the scheduler jobs, IAM binding, and service account. The live `min_instance_count` retains its last value until an operator updates it.

## R2 buckets

Buckets are declared in `prod.tfvars` under `r2_buckets` and provisioned by `modules/r2-bucket` (bucket + optional CORS + optional lifecycle).

- **`cgrs-images-prod`** — website images. CORS allows browser presigned `PUT` (direct upload).
- **`cgrs-documents-prod`** — society governance documents (minutes, agendas, financial records). Uploads are proxied server-side through the API, so CORS is **GET/HEAD only** (no browser PUT). A lifecycle rule aborts incomplete multipart uploads after 1 day.

**Keep CORS origins in sync:** both buckets use the same web-app origin list. If the deployed origins change, update both `cors_rules` blocks together — drift silently breaks presigned-GET downloads.

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
