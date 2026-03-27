variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "aws_access_key_id" {
  description = "AWS access key ID for R2"
  type        = string
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "AWS secret access key for R2"
  type        = string
  sensitive   = true
}

variable "aws_endpoint" {
  description = "R2 endpoint URL"
  type        = string
  default     = "https://645022b5181fa9285795e4936ee2b30a.r2.cloudflarestorage.com"
}

variable "aws_region" {
  description = "AWS region for R2"
  type        = string
  default     = "auto"
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for DNS records"
  type        = string
}

variable "r2_buckets" {
  description = "List of R2 bucket configurations"
  type = list(object({
    name            = string
    description     = optional(string, "")
    versioning      = optional(bool, true)
    website_enabled = optional(bool, false)
    tags            = optional(map(string), {})
  }))
  default = []
}

variable "dns_records" {
  description = "List of DNS records to create"
  type = list(object({
    name        = string
    type        = string
    content     = string
    ttl         = optional(number, 1)
    proxied     = optional(bool, false)
    description = optional(string, "")
  }))
  default = []
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
