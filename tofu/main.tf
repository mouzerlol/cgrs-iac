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

  enabled     = true
  bucket_name = each.value.name
  account_id  = var.cloudflare_account_id
  cors_rules  = try(each.value.cors_rules, [])
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

  # Non-sensitive env vars
  env_vars = {
    APP_NAME                = "CGRS API"
    APP_VERSION             = "0.1.0"
    DEBUG                   = "false"
    LOG_LEVEL               = "INFO"
    DATABASE_ECHO           = "false"
    TENANT_DEV_BYPASS       = "false"
    ALLOW_DEV_BYPASS        = "false"
    R2_BUCKET_NAME          = "cgrs-images-prod"
    CORS_ORIGINS            = var.cloud_run_cors_origins
    UVICORN_WORKERS         = "2"
  }

  # Sensitive env vars — values come from .envrc via TF_VAR_*
  secret_env_vars = var.cloud_run_secret_env_vars
}