output "id" {
  description = "ID of the R2 bucket"
  value       = cloudflare_r2_bucket.this.id
}

output "cors_configured" {
  description = "Whether a cloudflare_r2_bucket_cors resource was applied"
  value       = length(var.cors_rules) > 0
}

output "public_hostname" {
  description = "Hostname the bucket's objects are served from, or null when the bucket is private"
  value       = length(cloudflare_r2_custom_domain.this) > 0 ? cloudflare_r2_custom_domain.this[0].domain : null
}

output "public_access_enabled" {
  description = "Whether the bucket is readable without credentials, by either a custom domain or the managed r2.dev hostname"
  value       = length(cloudflare_r2_custom_domain.this) > 0 || length(cloudflare_r2_managed_domain.this) > 0
}