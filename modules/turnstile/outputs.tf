output "site_key" {
  description = "Turnstile widget site key (public)"
  value       = cloudflare_turnstile_widget.this.sitekey
  sensitive   = false
}

output "secret_key" {
  description = "Turnstile widget secret key (private, for server-side verification)"
  value       = cloudflare_turnstile_widget.this.secret
  sensitive   = true
}

output "widget_id" {
  description = "Turnstile widget ID"
  value       = cloudflare_turnstile_widget.this.id
}

output "account_id" {
  description = "Cloudflare account ID"
  value       = var.account_id
}
