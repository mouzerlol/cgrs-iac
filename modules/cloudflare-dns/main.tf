resource "cloudflare_dns_record" "this" {
  for_each = var.enabled ? { for record in var.records : record.name => record } : {}

  zone_id = var.zone_id
  name    = each.value.name
  type    = each.value.type
  content = each.value.content
  ttl     = lookup(each.value, "ttl", 1)
  proxied = lookup(each.value, "proxied", false)
  comment = lookup(each.value, "description", "")
}
