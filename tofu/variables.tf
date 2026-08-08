variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "aws_access_key_id" {
  description = "AWS access key ID for S3 backend"
  type        = string
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "AWS secret access key for S3 backend"
  type        = string
  sensitive   = true
}

variable "aws_endpoint" {
  description = "S3 endpoint URL for state storage"
  type        = string
  default     = "https://645022b5181fa9285795e4936ee2b30a.r2.cloudflarestorage.com"
}

variable "aws_region" {
  description = "AWS region for S3 backend"
  type        = string
  default     = "us-east-1"
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID for R2 buckets"
  type        = string
  sensitive   = true
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token for R2 bucket management"
  type        = string
  sensitive   = true
}

variable "web_app_origins" {
  description = "Browser origins the web application is served from. Every bucket whose CORS rule omits allowed_origins inherits this list, so an origin change is one edit rather than one per bucket. Must match the page URL exactly (scheme, host, port)."
  type        = list(string)
  default     = []
}

variable "r2_buckets" {
  description = "List of R2 bucket configurations. Adding a community means adding entries here — the module handles every property that differs between them."
  type = list(object({
    name            = string
    description     = optional(string, "")
    website_enabled = optional(bool, false)
    # Publicly readable, on a hostname the society owns. Omit both and the bucket is private.
    public_access_enabled = optional(bool, false)
    custom_domain = optional(object({
      name = string
      # Zone the hostname belongs to, by name. The id is looked up at plan time so no
      # opaque identifier lives in configuration and the zone stays Cloudflare-owned.
      zone    = string
      min_tls = optional(string, "1.2")
    }))
    cors_rules = optional(list(object({
      # Omitted means "the web application origins" — see var.web_app_origins.
      allowed_origins = optional(list(string))
      allowed_methods = list(string)
      allowed_headers = optional(list(string), ["Content-Type"])
      expose_headers  = optional(list(string), ["ETag", "Content-Length"])
      max_age_seconds = optional(number, 3600)
      rule_id         = optional(string)
    })), [])
    lifecycle_rules = optional(list(object({
      id                           = string
      prefix                       = optional(string, "")
      enabled                      = optional(bool, true)
      abort_multipart_max_age_days = optional(number)
    })), [])
  }))
  default = []
}

variable "tags" {
  description = "Common tags/labels to apply to all resources"
  type        = map(string)
  default     = {}
}

# --- GCP ---

variable "gcp_project_id" {
  description = "GCP project ID"
  type        = string
  sensitive   = true
}

variable "gcp_region" {
  description = "GCP region for resources"
  type        = string
  default     = "australia-southeast1"
}

# --- Artifact Registry ---

variable "artifact_registry_enabled" {
  description = "Enable GCP Artifact Registry"
  type        = bool
  default     = true
}

variable "artifact_registry_repository_id" {
  description = "Repository ID for the container registry"
  type        = string
  default     = "cgrs-api"
}

variable "artifact_registry_max_versions" {
  description = "Maximum image versions to retain per package (cleanup policy)"
  type        = number
  default     = 5
}

# --- Cloud Run ---

variable "cloud_run_enabled" {
  description = "Enable Cloud Run API service"
  type        = bool
  default     = true
}

variable "cloud_run_service_name" {
  description = "Name of the Cloud Run service"
  type        = string
  default     = "cgrs-api"
}

variable "cloud_run_image" {
  description = "Container image URL (REGION-docker.pkg.dev/PROJECT/REPO/IMAGE:TAG)"
  type        = string
}

variable "cloud_run_min_instances" {
  description = "Minimum instances. MUST stay 0: min-instance idle time is billed and blew the free tier by 10.6x. Warmth comes from the keep-warm ping job instead (see modules/cloud-run-keep-warm)."
  type        = number
  default     = 0

  validation {
    condition     = var.cloud_run_min_instances == 0
    error_message = "cloud_run_min_instances must be 0. A non-zero value bills idle instance time and leaves the Cloud Run free tier; use the keep-warm ping job instead. To override deliberately during an incident, use `gcloud run services update --min-instances=N` and revert."
  }
}

variable "cloud_run_max_instances" {
  description = "Maximum instances"
  type        = number
  default     = 2
}

variable "cloud_run_cpu" {
  description = "CPU allocation per instance"
  type        = string
  default     = "1"
}

variable "cloud_run_memory" {
  description = "Memory allocation per instance"
  type        = string
  default     = "512Mi"
}

variable "cloud_run_startup_cpu_boost" {
  description = "Allocate extra CPU during container startup only. Cuts cold start for the import-heavy FastAPI app; steady-state cost unchanged."
  type        = bool
  default     = true
}

variable "cloud_run_cors_origins" {
  description = "Comma-separated CORS origins for the API"
  type        = string
  default     = "https://cgrs.co.nz"
}

variable "cloud_run_secret_env_vars" {
  description = "Sensitive environment variables for the API (DATABASE_URL, API keys, etc.)"
  type        = map(string)
  default     = {}
  sensitive   = true
}

# --- Cloud Run Scheduled Scaling ---

variable "cloud_run_scheduler_enabled" {
  description = "Enable the keep-warm ping job (Cloud Scheduler GET /health during the warm window)"
  type        = bool
  default     = true
}

variable "cloud_run_ping_cron" {
  description = "Cron for the keep-warm ping, in cloud_run_schedule_timezone. Every 5 min inside the warm window; a 3x margin against Cloud Run's documented ~15 min idle-instance retention."
  type        = string
  default     = "*/5 6-22 * * *"
}

variable "cloud_run_warm_window_start_hour" {
  description = "Hour the warm window opens. Surfaced to the frontend cold-start banner via cloud_run_sleep_window; keep consistent with cloud_run_ping_cron."
  type        = number
  default     = 6
}

variable "cloud_run_warm_window_end_hour" {
  description = "Hour the warm window closes. Surfaced to the frontend cold-start banner via cloud_run_sleep_window; keep consistent with cloud_run_ping_cron."
  type        = number
  default     = 23
}

variable "cloud_run_schedule_timezone" {
  description = "IANA time zone for the keep-warm cron. Pacific/Auckland is DST-aware."
  type        = string
  default     = "Pacific/Auckland"
}

# --- Outbound Email Dispatch (Cloud Tasks — ADR 022) ---

variable "email_dispatch_enabled" {
  description = "Provision Cloud Tasks queue + reconcile scheduler and enable Cloud Tasks dispatch in the API."
  type        = bool
  default     = false
}

variable "email_dispatch_base_url" {
  description = "Stable public base URL of the API (e.g. the run.app service URL or api.cgrs.co.nz). The internal /send and /reconcile endpoint URLs are derived from it. Required when email_dispatch_enabled."
  type        = string
  default     = ""
}

variable "email_dispatch_queue_id" {
  description = "Cloud Tasks queue id for outbound email."
  type        = string
  default     = "email-outbound"
}

variable "email_dispatch_sa_account_id" {
  description = "Account id (before @<project>.iam) of the email dispatch service account."
  type        = string
  default     = "email-dispatch"
}

variable "email_reconcile_cron" {
  description = "Cron schedule for the reconcile sweep, in cloud_run_schedule_timezone. Default runs hourly only during the warm window — Neon Free's fixed 5-min autosuspend makes overnight wakes wasteful."
  type        = string
  default     = "0 6-23 * * *"
}

# --- Billing Export (BigQuery) ---

variable "billing_export_enabled" {
  description = "Create the BigQuery dataset that receives the Cloud Billing Standard usage cost export. Creates the destination only — linking the billing account to it is a Console-only manual step, so enabling this alone leaves the export inert."
  type        = bool
  default     = false
}

variable "billing_export_dataset_id" {
  description = "BigQuery dataset ID for the billing export. Must match the dataset selected in the Console billing-export step; renaming it here creates a new empty dataset and orphans the exported history."
  type        = string
  default     = "billing_export"
}

# --- Turnstile ---

variable "turnstile_enabled" {
  description = "Enable Cloudflare Turnstile CAPTCHA"
  type        = bool
  default     = true
}

variable "turnstile_name" {
  description = "Name for the Turnstile widget"
  type        = string
  default     = "CGRS Management Request"
}

variable "turnstile_domains" {
  description = "Hostnames where the Turnstile widget is embedded (each hostname must be listed; www is not implied)."
  type        = list(string)
  default     = ["cgrs.co.nz", "www.cgrs.co.nz", "localhost"]
}

variable "turnstile_mode" {
  description = "Turnstile widget mode: non-interactive, invisible, or managed"
  type        = string
  default     = "managed"
  validation {
    condition     = contains(["non-interactive", "invisible", "managed"], var.turnstile_mode)
    error_message = "Mode must be one of: non-interactive, invisible, managed"
  }
}
