variable "enabled" {
  description = "Whether to create the bucket"
  type        = bool
  default     = true
}

variable "bucket_name" {
  description = "Name of the R2 bucket"
  type        = string
}

variable "account_id" {
  description = "Cloudflare account ID"
  type        = string
}

variable "website_enabled" {
  description = "Enable static website hosting"
  type        = bool
  default     = false
}

variable "routing_rules" {
  description = "Routing rules for website configuration (JSON string)"
  type        = string
  default     = null
}

variable "cors_rules" {
  description = "Browser CORS rules for direct uploads and GETs (e.g. presigned PUT/GET from the web app). Empty list skips cloudflare_r2_bucket_cors."
  type = list(object({
    allowed_origins = list(string)
    allowed_methods = list(string)
    allowed_headers = optional(list(string), ["Content-Type"])
    expose_headers  = optional(list(string), ["ETag", "Content-Length"])
    max_age_seconds = optional(number, 3600)
    rule_id         = optional(string)
  }))
  default = []
}