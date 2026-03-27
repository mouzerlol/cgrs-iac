output "bucket_id" {
  description = "ID of the R2 bucket"
  value       = var.enabled ? aws_s3_bucket.this[0].id : null
}

output "bucket_arn" {
  description = "ARN of the R2 bucket"
  value       = var.enabled ? aws_s3_bucket.this[0].arn : null
}

output "bucket_name" {
  description = "Name of the R2 bucket"
  value       = var.enabled ? aws_s3_bucket.this[0].bucket : null
}

output "bucket_domain_name" {
  description = "Domain name of the R2 bucket"
  value       = var.enabled ? aws_s3_bucket.this[0].bucket_domain_name : null
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the R2 bucket"
  value       = var.enabled ? aws_s3_bucket.this[0].bucket_regional_domain_name : null
}

output "website_endpoint" {
  description = "Website endpoint (if website hosting is enabled)"
  value       = var.enabled && var.website_enabled ? aws_s3_bucket_website_configuration.this[0].website_endpoint : null
}
