output "record_ids" {
  description = "Map of record names to their IDs"
  value = var.enabled ? {
    for name, record in cloudflare_dns_record.this :
    name => record.id
  } : {}
}

output "record_fqdns" {
  description = "DNS record name field as returned by Cloudflare (often FQDN for the record)"
  value = var.enabled ? [
    for record in cloudflare_dns_record.this :
    record.name
  ] : []
}

output "records_created" {
  description = "Number of records created"
  value       = var.enabled ? length(cloudflare_dns_record.this) : 0
}
