variable "account_id" {
  description = "Cloudflare account ID"
  type        = string
  sensitive   = true
}

variable "name" {
  description = "Turnstile widget name"
  type        = string
  default     = "CGRS Management Request CAPTCHA"
}

variable "domains" {
  description = "List of domains where the Turnstile widget will be used"
  type        = list(string)
  default     = ["cgrs.co.nz"]
}

variable "mode" {
  description = "Widget mode: non-interactive, invisible, or managed"
  type        = string
  default     = "managed"
  validation {
    condition     = contains(["non-interactive", "invisible", "managed"], var.mode)
    error_message = "Mode must be one of: non-interactive, invisible, managed"
  }
}
