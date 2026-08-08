terraform {
  required_version = ">= 1.10"

  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.67"
    }
    cloudflare = {
      source  = "hashicorp/cloudflare"
      version = "~> 5.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  alias = "backend"

  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
  region     = var.aws_region

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3 = var.aws_endpoint
  }
}

# cloudflare_r2_bucket calls api.cloudflare.com — needs an API token (not R2 S3 access keys).
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# GCP provider — uses Application Default Credentials (gcloud auth application-default login).
# No explicit credentials needed; ADC is picked up automatically.
provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# Zones a bucket binds a hostname to. Read, never managed: the zone holds records this
# estate does not own (Vercel, Clerk, email), so declaring it as a resource would put the
# whole domain inside `tofu destroy`'s blast radius for the sake of one identifier.
# Requires the Cloudflare token to carry Zone:Read on each zone named here.
data "cloudflare_zone" "custom_domain" {
  for_each = toset([
    for bucket in var.r2_buckets : bucket.custom_domain.zone
    if bucket.custom_domain != null
  ])

  filter = {
    name    = each.value
    account = { id = var.cloudflare_account_id }
  }
}

module "r2_buckets" {
  source = "../modules/r2-bucket"

  for_each = { for bucket in var.r2_buckets : bucket.name => bucket }

  enabled     = true
  bucket_name = each.value.name
  account_id  = var.cloudflare_account_id

  # A rule that names no origins takes the shared web application list, so the origins are
  # declared once for the whole estate rather than repeated in every bucket declaration.
  cors_rules = [
    for r in each.value.cors_rules : merge(r, {
      allowed_origins = coalesce(r.allowed_origins, var.web_app_origins)
    })
  ]

  lifecycle_rules       = each.value.lifecycle_rules
  public_access_enabled = each.value.public_access_enabled

  custom_domain = each.value.custom_domain == null ? null : {
    name    = each.value.custom_domain.name
    zone_id = data.cloudflare_zone.custom_domain[each.value.custom_domain.zone].id
    min_tls = each.value.custom_domain.min_tls
  }
}

module "turnstile" {
  source = "../modules/turnstile"

  count = var.turnstile_enabled ? 1 : 0

  account_id = var.cloudflare_account_id
  name       = var.turnstile_name
  domains    = var.turnstile_domains
  mode       = var.turnstile_mode
}

module "artifact_registry" {
  source = "../modules/artifact-registry"

  count = var.artifact_registry_enabled ? 1 : 0

  project_id           = var.gcp_project_id
  location             = var.gcp_region
  repository_id        = var.artifact_registry_repository_id
  description          = "CGRS API container images"
  labels               = var.tags
  cleanup_max_versions = var.artifact_registry_max_versions
}

locals {
  email_dispatch_on   = var.cloud_run_enabled && var.email_dispatch_enabled && var.email_dispatch_base_url != ""
  email_send_url      = "${var.email_dispatch_base_url}/api/v1/internal/email/send"
  email_reconcile_url = "${var.email_dispatch_base_url}/api/v1/internal/email/reconcile"
  # Deterministic SA email (not the module output) so the API service env does not depend
  # on the email_dispatch module — that module depends on the service (one-way), avoiding a cycle.
  email_dispatch_sa_email = "${var.email_dispatch_sa_account_id}@${var.gcp_project_id}.iam.gserviceaccount.com"
  email_dispatch_env = local.email_dispatch_on ? {
    EMAIL_DISPATCH_VIA_CLOUD_TASKS = "true"
    GCP_PROJECT_ID                 = var.gcp_project_id
    CLOUD_TASKS_LOCATION           = var.gcp_region
    CLOUD_TASKS_QUEUE              = var.email_dispatch_queue_id
    EMAIL_SEND_ENDPOINT_URL        = local.email_send_url
    EMAIL_RECONCILE_ENDPOINT_URL   = local.email_reconcile_url
    EMAIL_DISPATCH_SA_EMAIL        = local.email_dispatch_sa_email
    # Single shared OIDC audience for BOTH internal endpoints so token verification
    # matches regardless of which endpoint (send vs reconcile) is called.
    EMAIL_DISPATCH_OIDC_AUDIENCE = local.email_send_url
  } : {}
}

module "cloud_run_api" {
  source = "../modules/cloud-run"

  count = var.cloud_run_enabled ? 1 : 0

  project_id   = var.gcp_project_id
  location     = var.gcp_region
  service_name = var.cloud_run_service_name
  image        = var.cloud_run_image
  labels       = var.tags

  # Scaling — free tier friendly
  min_instances = var.cloud_run_min_instances
  max_instances = var.cloud_run_max_instances
  cpu           = var.cloud_run_cpu
  memory        = var.cloud_run_memory

  # Cold start is dominated by CPU-bound Python imports on a single vCPU; boost applies
  # to the startup window only, so steady-state cost is unaffected.
  startup_cpu_boost = var.cloud_run_startup_cpu_boost

  # Public API
  allow_unauthenticated = true

  # Non-sensitive env vars (merged with Cloud Tasks dispatch vars when enabled)
  env_vars = merge({
    APP_NAME                      = "CGRS API"
    APP_VERSION                   = "0.1.0"
    DEBUG                         = "false"
    LOG_LEVEL                     = "INFO"
    DATABASE_ECHO                 = "false"
    TENANT_DEV_BYPASS             = "false"
    ALLOW_DEV_BYPASS              = "false"
    R2_BUCKET_NAME                = "cgrs-images-prod"
    R2_DOCUMENTS_BUCKET_NAME      = "cgrs-documents-prod"
    R2_GROUND_REPORTS_BUCKET_NAME = "cgrs-ground-reports-prod"
    # Blog bucket names come from the API's own defaults; these two are the pieces it cannot
    # know. Neither is secret — the domain is public by definition and the URL is a public
    # route. Only the shared secret sent to it lives in secret_env_vars.
    BLOG_CONTENT_DOMAIN = "content.cgrs.co.nz"
    # `www`, not the apex. The apex 307s to www, and the API's revalidate client does not
    # follow redirects — it would read the 307 as success (it only treats >=400 as refused)
    # and report a signal that never arrived. Benign in effect (the post still appears when
    # the manifest's window lapses) but silently wrong, which is worse than a logged failure.
    BLOG_REVALIDATE_URL = "https://www.cgrs.co.nz/api/blog/revalidate"
    CORS_ORIGINS        = var.cloud_run_cors_origins
    # 1, not 2: the service has 1 vCPU, so a second uvicorn worker cannot run in parallel —
    # it only duplicates the app import and contends for the same core. Measured locally at
    # 1 vCPU: 2 workers = 8.52s cold start, 1 worker = 4.89s. FastAPI is async, so one worker
    # covers this service's concurrency. Raise only alongside cloud_run_cpu.
    UVICORN_WORKERS = "1"
  }, local.email_dispatch_env)

  # Sensitive env vars — values come from .envrc via TF_VAR_*
  secret_env_vars = var.cloud_run_secret_env_vars
}

# NOTE: the module BLOCK name stays `cloud_run_scheduler` even though the module is now
# `cloud-run-keep-warm`. Renaming the block would re-address every resource inside it in state.
# Module `source` paths are not recorded in state, so renaming the directory is free; renaming
# the block is not. Cosmetic mismatch is cheaper than the state churn.
module "cloud_run_scheduler" {
  source = "../modules/cloud-run-keep-warm"

  count = var.cloud_run_enabled && var.cloud_run_scheduler_enabled ? 1 : 0

  project_id   = var.gcp_project_id
  location     = var.gcp_region
  service_name = var.cloud_run_service_name

  # Ping the service's own URL. Taken from the module output so it cannot drift from the
  # actual service, and so a service replacement re-points the job automatically.
  service_url = one(module.cloud_run_api[*].service_url)

  ping_cron              = var.cloud_run_ping_cron
  warm_window_start_hour = var.cloud_run_warm_window_start_hour
  warm_window_end_hour   = var.cloud_run_warm_window_end_hour
  time_zone              = var.cloud_run_schedule_timezone

  labels = var.tags

  depends_on = [module.cloud_run_api]
}

# BigQuery destination for the Cloud Billing Standard usage cost export. Gated so a fresh
# environment can be stood up without it; note that enabling it here creates the dataset only —
# linking the billing account to it is a Console-only manual step (see the module comment and
# environments/prod/README.md).
module "billing_export" {
  source = "../modules/billing-export"

  count = var.billing_export_enabled ? 1 : 0

  project_id = var.gcp_project_id
  location   = var.gcp_region
  dataset_id = var.billing_export_dataset_id

  labels = var.tags
}

module "email_dispatch" {
  source = "../modules/email-dispatch"

  count = local.email_dispatch_on ? 1 : 0

  project_id   = var.gcp_project_id
  location     = var.gcp_region
  service_name = var.cloud_run_service_name

  queue_id                    = var.email_dispatch_queue_id
  dispatch_service_account_id = var.email_dispatch_sa_account_id
  send_endpoint_url           = local.email_send_url
  reconcile_endpoint_url      = local.email_reconcile_url
  # Shared audience (= send URL) so the reconcile scheduler's OIDC token verifies the
  # same way the send tasks do. Keep in sync with EMAIL_DISPATCH_OIDC_AUDIENCE above.
  oidc_audience  = local.email_send_url
  reconcile_cron = var.email_reconcile_cron
  time_zone      = var.cloud_run_schedule_timezone

  labels = var.tags

  depends_on = [module.cloud_run_api]
}