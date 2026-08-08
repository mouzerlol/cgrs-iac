output "environment" {
  description = "Current environment"
  value       = var.environment
}

output "r2_buckets" {
  description = "R2 bucket details"
  value = {
    for name, bucket in module.r2_buckets :
    name => {
      id                    = bucket.id
      cors_configured       = bucket.cors_configured
      public_access_enabled = bucket.public_access_enabled
      public_hostname       = bucket.public_hostname
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

# Surfaced for the frontend build pipeline. The cold-start banner reads these
# (via NEXT_PUBLIC_SLEEP_WINDOW_*_HOUR) to know when to render. Keeping the
# IaC values as the source of truth prevents the frontend banner from drifting
# out of sync with the actual keep-warm window.
#
# The key names are intentionally unchanged from the min-instance era so no frontend change is
# needed; they now come from the explicit warm-window hour variables rather than being parsed
# out of the retired scale-up/scale-down crons. Semantics are slightly weaker than before:
# inside the window the service is USUALLY warm (best-effort ping) rather than GUARANTEED warm
# (paid min-instance). The banner does not claim either, so its copy stays accurate.
output "cloud_run_sleep_window" {
  description = "Warm-window hours (consumed by the frontend cold-start banner as NEXT_PUBLIC_SLEEP_WINDOW_*_HOUR)"
  value = var.cloud_run_enabled && var.cloud_run_scheduler_enabled ? {
    scale_up_hour   = one(module.cloud_run_scheduler[*].scale_up_hour)
    scale_down_hour = one(module.cloud_run_scheduler[*].scale_down_hour)
    time_zone       = one(module.cloud_run_scheduler[*].schedule_time_zone)
  } : null
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