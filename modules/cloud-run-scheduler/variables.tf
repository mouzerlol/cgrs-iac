variable "project_id" {
  description = "GCP project ID containing the Cloud Run service to scale"
  type        = string
}

variable "location" {
  description = "GCP region of the target Cloud Run service (e.g. australia-southeast1)"
  type        = string
}

variable "service_name" {
  description = "Name of the target Cloud Run service whose min_instance_count will be scheduled"
  type        = string
}

variable "service_account_id" {
  description = "Account ID for the dedicated scheduler service account (the part before @<project>.iam.gserviceaccount.com)"
  type        = string
  default     = "cloud-run-scheduler"
}

variable "warm_min_instances" {
  description = "Min instance count to set during the warm window"
  type        = number
  default     = 1
}

variable "scale_up_cron" {
  description = "Cron expression for the scale-up job (in time_zone)"
  type        = string
  default     = "0 6 * * *"
}

variable "scale_down_cron" {
  description = "Cron expression for the scale-down job (in time_zone)"
  type        = string
  default     = "0 23 * * *"
}

variable "time_zone" {
  description = "IANA time zone for cron evaluation. Pacific/Auckland is DST-aware."
  type        = string
  default     = "Pacific/Auckland"
}

variable "runtime_service_account_email" {
  description = "Runtime service account used by the target Cloud Run service. The scheduler SA needs roles/iam.serviceAccountUser on this SA in order to update the service. Empty string = default Compute Engine SA (resolved automatically)."
  type        = string
  default     = ""
}

variable "labels" {
  description = "Labels to apply to scheduler jobs (lowercased per GCP rules)"
  type        = map(string)
  default     = {}
}
