resource "cloudflare_r2_bucket" "this" {
  account_id = var.account_id
  name       = var.bucket_name
}

resource "cloudflare_r2_bucket_cors" "this" {
  count = length(var.cors_rules) > 0 ? 1 : 0

  account_id  = var.account_id
  bucket_name = var.bucket_name

  rules = [
    for r in var.cors_rules : {
      allowed = {
        origins = r.allowed_origins
        methods = r.allowed_methods
        headers = r.allowed_headers
      }
      expose_headers  = r.expose_headers
      max_age_seconds = r.max_age_seconds
      id              = try(r.rule_id, null)
    }
  ]

  depends_on = [cloudflare_r2_bucket.this]
}

# Cloudflare's managed r2.dev hostname. Guarded off by default: a bucket with neither this
# nor a custom domain is private, which is what every bucket in this estate but the blog one is.
resource "cloudflare_r2_managed_domain" "this" {
  count = var.public_access_enabled ? 1 : 0

  account_id  = var.account_id
  bucket_name = var.bucket_name
  enabled     = true

  depends_on = [cloudflare_r2_bucket.this]
}

# Binding a hostname is what makes a bucket world-readable and puts it behind Cloudflare's
# cache. Cloudflare creates the CNAME as part of the binding, so there is no separate DNS
# resource here to drift out of step with it.
resource "cloudflare_r2_custom_domain" "this" {
  count = var.custom_domain != null ? 1 : 0

  account_id  = var.account_id
  bucket_name = var.bucket_name
  domain      = var.custom_domain.name
  zone_id     = var.custom_domain.zone_id
  enabled     = true
  min_tls     = var.custom_domain.min_tls

  depends_on = [cloudflare_r2_bucket.this]
}

resource "cloudflare_r2_bucket_lifecycle" "this" {
  count = length(var.lifecycle_rules) > 0 ? 1 : 0

  account_id  = var.account_id
  bucket_name = var.bucket_name

  rules = [
    for r in var.lifecycle_rules : {
      id         = r.id
      enabled    = r.enabled
      conditions = { prefix = r.prefix }
      # Reclaim orphaned multipart fragments. max_age is in seconds; convert from days.
      abort_multipart_uploads_transition = r.abort_multipart_max_age_days != null ? {
        condition = {
          max_age = r.abort_multipart_max_age_days * 86400
          type    = "Age"
        }
      } : null
    }
  ]

  depends_on = [cloudflare_r2_bucket.this]
}