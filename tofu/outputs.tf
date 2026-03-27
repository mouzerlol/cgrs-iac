output "environment" {
  description = "Current environment"
  value       = var.environment
}

output "r2_buckets" {
  description = "R2 bucket details"
  value = {
    for name, bucket in module.r2_buckets :
    name => {
      id               = bucket.bucket_id
      arn              = bucket.bucket_arn
      domain_name      = bucket.bucket_domain_name
      website_endpoint = bucket.website_endpoint
    }
  }
}

output "dns_records" {
  description = "DNS record details"
  value = {
    record_ids   = module.dns_records.record_ids
    record_fqdns = module.dns_records.record_fqdns
    count        = module.dns_records.records_created
  }
}

output "providers" {
  description = "Provider versions"
  value = {
    aws        = "~> 5.0"
    cloudflare = "~> 4.0"
  }
}
