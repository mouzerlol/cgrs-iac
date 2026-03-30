output "id" {
  description = "ID of the R2 bucket"
  value       = cloudflare_r2_bucket.this.id
}

output "cors_configured" {
  description = "Whether a cloudflare_r2_bucket_cors resource was applied"
  value       = length(var.cors_rules) > 0
}