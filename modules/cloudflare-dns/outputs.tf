output "record_ids" {
  description = "Map of record names to their IDs"
  value = var.enabled ? {
    for name, record in cloudflare_record.this :
    name => record.id
  } : {}
}

output "record_fqdns" {
  description = "List of fully qualified domain names"
  value = var.enabled ? [
    for record in cloudflare_record.this :
    record.fqdn
  ] : []
}

output "records_created" {
  description = "Number of records created"
  value       = var.enabled ? length(cloudflare_record.this) : 0
}
