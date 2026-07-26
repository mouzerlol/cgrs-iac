variable "project_id" {
  description = "GCP project ID containing the Cloud Run service to keep warm"
  type        = string
}

variable "location" {
  description = "GCP region of the target Cloud Run service (e.g. australia-southeast1)"
  type        = string
}

variable "service_name" {
  description = "Name of the target Cloud Run service to keep warm"
  type        = string
}

variable "service_url" {
  description = "Base HTTPS URL of the target Cloud Run service (no trailing slash), e.g. https://cgrs-api-xxxx.a.run.app"
  type        = string

  validation {
    condition     = can(regex("^https://[^/]+$", var.service_url))
    error_message = "service_url must be an https:// URL with no path and no trailing slash."
  }
}

variable "health_path" {
  description = "Path to ping. MUST be database-free and cheap: it is hit ~204 times/day, so a DB call here would wake Neon on every ping and inflate billed request duration."
  type        = string
  default     = "/health"
}

variable "ping_cron" {
  description = "Cron expression for the keep-warm ping, in time_zone. Default fires every 5 minutes from 06:00 to 22:55 — a 3x margin against Cloud Run's documented (but not guaranteed) ~15 min idle-instance retention."
  type        = string
  default     = "*/5 6-22 * * *"
}

variable "warm_window_start_hour" {
  description = "Hour (in time_zone) the warm window opens. Surfaced to the frontend cold-start banner; keep consistent with ping_cron."
  type        = number
  default     = 6
}

variable "warm_window_end_hour" {
  description = "Hour (in time_zone) the warm window closes. Surfaced to the frontend cold-start banner; keep consistent with ping_cron."
  type        = number
  default     = 23
}

variable "time_zone" {
  description = "IANA time zone for cron evaluation. Pacific/Auckland is DST-aware."
  type        = string
  default     = "Pacific/Auckland"
}

variable "labels" {
  description = "Labels for resources that support them. Cloud Scheduler jobs do not, so this is currently unused; kept for interface consistency with the other modules."
  type        = map(string)
  default     = {}
}
