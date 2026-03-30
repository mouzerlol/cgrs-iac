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