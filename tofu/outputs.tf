output "environment" {
  description = "Current environment"
  value       = var.environment
}

output "r2_buckets" {
  description = "R2 bucket details"
  value = {
    for name, bucket in module.r2_buckets :
    name => {
      id               = bucket.id
      cors_configured  = bucket.cors_configured
    }
  }
}

output "providers" {
  description = "Provider versions"
  value = {
    aws       = "~> 4.67"
    cloudflare = "~> 5.0"
  }
}