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
  }
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