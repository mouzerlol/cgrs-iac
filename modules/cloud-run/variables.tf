variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "location" {
  description = "GCP region for the Cloud Run service"
  type        = string
  default     = "australia-southeast1"
}

variable "service_name" {
  description = "Name of the Cloud Run service"
  type        = string
}

variable "image" {
  description = "Full container image URL (e.g. REGION-docker.pkg.dev/PROJECT/REPO/IMAGE:TAG)"
  type        = string
}

variable "port" {
  description = "Container port to expose"
  type        = number
  default     = 8000
}

variable "env_vars" {
  description = "Environment variables to inject into the container (non-sensitive)"
  type        = map(string)
  default     = {}
}

variable "secret_env_vars" {
  description = "Sensitive environment variables (marked sensitive to prevent logging)"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "min_instances" {
  description = "Minimum number of instances (0 = scale to zero)"
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Maximum number of instances"
  type        = number
  default     = 2
}

variable "cpu" {
  description = "CPU allocation (e.g. '1' for 1 vCPU)"
  type        = string
  default     = "1"
}

variable "memory" {
  description = "Memory allocation (e.g. '512Mi', '1Gi')"
  type        = string
  default     = "512Mi"
}

variable "startup_cpu_boost" {
  description = "Allocate extra CPU during container startup only. Shortens cold start for import-heavy Python apps; does not affect steady-state cost."
  type        = bool
  default     = true
}

variable "timeout" {
  description = "Request timeout in seconds"
  type        = number
  default     = 300
}

variable "allow_unauthenticated" {
  description = "Allow public access without authentication"
  type        = bool
  default     = true
}

variable "labels" {
  description = "Labels to apply to the service"
  type        = map(string)
  default     = {}
}
