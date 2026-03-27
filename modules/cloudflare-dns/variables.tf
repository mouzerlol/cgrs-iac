variable "enabled" {
  description = "Whether to create DNS records"
  type        = bool
  default     = true
}

variable "zone_id" {
  description = "Cloudflare zone ID"
  type        = string
}

variable "records" {
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
