variable "project_id" {
  description = "GCP project ID that owns the billing export dataset"
  type        = string
}

variable "location" {
  description = "BigQuery location for the dataset. Keep it in the same region as the workload being costed so queries stay regional (e.g. australia-southeast1)."
  type        = string
  default     = "australia-southeast1"
}

variable "dataset_id" {
  description = "BigQuery dataset ID to receive the Standard usage cost export. Must match the dataset selected in the Console billing-export step."
  type        = string
  default     = "billing_export"

  validation {
    # Length is checked separately: Go's regexp engine rejects repeat counts above 1000,
    # so a {1,1024} quantifier would make the pattern itself invalid and fail every value.
    condition     = can(regex("^[A-Za-z0-9_]+$", var.dataset_id)) && length(var.dataset_id) <= 1024
    error_message = "dataset_id may contain only letters, numbers and underscores, max 1024 characters (BigQuery dataset naming rules)."
  }
}

variable "description" {
  description = "Human-readable description of the dataset"
  type        = string
  default     = "Cloud Billing Standard usage cost export (linked manually in the Console — see environments/prod/README.md)"
}

variable "labels" {
  description = "Labels to apply to the dataset. Keys and values are lowercased, as GCP labels require."
  type        = map(string)
  default     = {}
}
