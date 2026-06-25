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

module "r2_buckets" {
  source = "../modules/r2-bucket"

  for_each = { for bucket in var.r2_buckets : bucket.name => bucket }

  enabled         = true
  bucket_name     = each.value.name
  account_id      = var.cloudflare_account_id
  cors_rules      = try(each.value.cors_rules, [])
  lifecycle_rules = try(each.value.lifecycle_rules, [])
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
    CORS_ORIGINS                  = var.cloud_run_cors_origins
    UVICORN_WORKERS               = "2"
  }, local.email_dispatch_env)

  # Sensitive env vars — values come from .envrc via TF_VAR_*
  secret_env_vars = var.cloud_run_secret_env_vars
}

module "cloud_run_scheduler" {
  source = "../modules/cloud-run-scheduler"

  count = var.cloud_run_enabled && var.cloud_run_scheduler_enabled ? 1 : 0

  project_id   = var.gcp_project_id
  location     = var.gcp_region
  service_name = var.cloud_run_service_name

  warm_min_instances = var.cloud_run_warm_min_instances
  scale_up_cron      = var.cloud_run_scale_up_cron
  scale_down_cron    = var.cloud_run_scale_down_cron
  time_zone          = var.cloud_run_schedule_timezone

  labels = var.tags

  depends_on = [module.cloud_run_api]
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