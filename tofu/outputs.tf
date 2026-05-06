output "environment" {
  description = "Current environment"
  value       = var.environment
}

output "r2_buckets" {
  description = "R2 bucket details"
  value = {
    for name, bucket in module.r2_buckets :
    name => {
      id              = bucket.id
      cors_configured = bucket.cors_configured
    }
  }
}

output "providers" {
  description = "Provider versions"
  value = {
    aws        = "~> 4.67"
    cloudflare = "~> 5.0"
    google     = "~> 6.0"
  }
}

output "artifact_registry_url" {
  description = "Docker push/pull URL for the Artifact Registry repository"
  value       = var.artifact_registry_enabled ? one(module.artifact_registry[*].repository_url) : null
  sensitive   = true
}

output "cloud_run_url" {
  description = "The public URL of the Cloud Run API service"
  value       = var.cloud_run_enabled ? one(module.cloud_run_api[*].service_url) : null
}

output "cloud_run_revision" {
  description = "The latest ready revision of the Cloud Run service"
  value       = var.cloud_run_enabled ? one(module.cloud_run_api[*].latest_revision) : null
}

output "turnstile_site_key" {
  description = "Cloudflare Turnstile site key (public)"
  value       = var.turnstile_enabled ? one(module.turnstile[*].site_key) : null
}

output "turnstile_secret_key" {
  description = "Cloudflare Turnstile secret key (private, for backend verification)"
  value       = var.turnstile_enabled ? one(module.turnstile[*].secret_key) : null
  sensitive   = true
}

output "turnstile_widget_id" {
  description = "Cloudflare Turnstile widget ID"
  value       = var.turnstile_enabled ? one(module.turnstile[*].widget_id) : null
}