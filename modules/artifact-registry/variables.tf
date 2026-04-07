variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "location" {
  description = "GCP region for the repository (e.g. australia-southeast1)"
  type        = string
  default     = "australia-southeast1"
}

variable "repository_id" {
  description = "Repository identifier (e.g. cgrs-api)"
  type        = string
}

variable "description" {
  description = "Human-readable description of the repository"
  type        = string
  default     = ""
}

variable "format" {
  description = "Repository format: DOCKER, NPM, PYTHON, etc."
  type        = string
  default     = "DOCKER"
  validation {
    condition     = contains(["DOCKER", "NPM", "PYTHON", "MAVEN", "APT", "YUM", "GO"], var.format)
    error_message = "Format must be one of: DOCKER, NPM, PYTHON, MAVEN, APT, YUM, GO"
  }
}

variable "immutable_tags" {
  description = "Prevent tag overwriting (recommended for production traceability)"
  type        = bool
  default     = false
}

variable "cleanup_max_versions" {
  description = "Maximum number of image versions to retain per package (0 = no cleanup)"
  type        = number
  default     = 5
}

variable "labels" {
  description = "Labels to apply to the repository"
  type        = map(string)
  default     = {}
}
