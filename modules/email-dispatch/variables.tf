variable "project_id" {
  description = "GCP project id hosting Cloud Tasks, the queue, and the reconcile scheduler job."
  type        = string
}

variable "location" {
  description = "Region for the Cloud Tasks queue and Cloud Scheduler job (e.g. australia-southeast1)."
  type        = string
}

variable "service_name" {
  description = "Name of the Cloud Run API service the dispatch SA may invoke."
  type        = string
}

variable "queue_id" {
  description = "Cloud Tasks queue id for outbound email dispatch."
  type        = string
  default     = "email-outbound"
}

variable "dispatch_service_account_id" {
  description = "Account id (before @<project>.iam) for the dispatch service account."
  type        = string
  default     = "email-dispatch"
}

variable "runtime_service_account_email" {
  description = "Cloud Run runtime SA that creates Cloud Tasks (needs actAs on the dispatch SA). Empty = default Compute Engine SA."
  type        = string
  default     = ""
}

variable "send_endpoint_url" {
  description = "Absolute URL of POST /api/v1/internal/email/send (Cloud Tasks target)."
  type        = string
}

variable "reconcile_endpoint_url" {
  description = "Absolute URL of POST /api/v1/internal/email/reconcile (Cloud Scheduler target)."
  type        = string
}

variable "oidc_audience" {
  description = "OIDC token audience for the internal endpoints. Empty = use each endpoint URL as audience."
  type        = string
  default     = ""
}

variable "reconcile_cron" {
  description = "Cron schedule for the reconcile sweep (in time_zone)."
  type        = string
  default     = "0 6-23 * * *" # hourly during the warm window only
}

variable "time_zone" {
  description = "IANA time zone for the reconcile cron."
  type        = string
  default     = "Pacific/Auckland"
}

variable "max_attempts" {
  description = "Cloud Tasks max delivery attempts per task."
  type        = number
  default     = 5
}

variable "min_backoff" {
  description = "Cloud Tasks min retry backoff."
  type        = string
  default     = "60s"
}

variable "max_backoff" {
  description = "Cloud Tasks max retry backoff. Keep below the reconcile stale threshold (30m) to avoid colliding with retries."
  type        = string
  default     = "900s"
}

variable "max_doublings" {
  description = "Cloud Tasks max backoff doublings."
  type        = number
  default     = 4
}

variable "log_sampling_ratio" {
  description = "Fraction of task dispatch operations logged to Cloud Logging (0.0–1.0). 1.0 = full visibility; free at low volume."
  type        = number
  default     = 1.0
}

variable "labels" {
  description = "Resource labels."
  type        = map(string)
  default     = {}
}
