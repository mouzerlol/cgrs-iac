variable "enabled" {
  description = "Whether to create the bucket"
  type        = bool
  default     = true
}

variable "bucket_name" {
  description = "Name of the R2 bucket"
  type        = string
}

variable "versioning_enabled" {
  description = "Enable versioning for the bucket"
  type        = bool
  default     = true
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

variable "tags" {
  description = "Tags to apply to the bucket"
  type        = map(string)
  default     = {}
}
