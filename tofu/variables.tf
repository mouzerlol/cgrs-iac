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

variable "r2_buckets" {
  description = "List of R2 bucket configurations"
  type = list(object({
    name            = string
    description     = optional(string, "")
    website_enabled = optional(bool, false)
    cors_rules = optional(list(object({
      allowed_origins = list(string)
      allowed_methods = list(string)
      allowed_headers = optional(list(string), ["Content-Type"])
      expose_headers  = optional(list(string), ["ETag", "Content-Length"])
      max_age_seconds = optional(number, 3600)
      rule_id         = optional(string)
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
  description = "Minimum instances (0 = scale to zero for free tier)"
  type        = number
  default     = 0
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
  description = "Domains for Turnstile widget (including localhost for dev)"
  type        = list(string)
  default     = ["cgrs.co.nz", "localhost"]
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
