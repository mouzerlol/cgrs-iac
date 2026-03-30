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
      allowed_origins   = list(string)
      allowed_methods   = list(string)
      allowed_headers   = optional(list(string), ["Content-Type"])
      expose_headers    = optional(list(string), ["ETag", "Content-Length"])
      max_age_seconds   = optional(number, 3600)
      rule_id           = optional(string)
    })), [])
  }))
  default = []
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
