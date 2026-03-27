# Cloudflare DNS Module

This module creates DNS records in Cloudflare.

## Usage

```hcl
module "dns_records" {
  source = "../../modules/cloudflare-dns"

  zone_id = "example_zone_id"
  records = [
    {
      name    = "www"
      type    = "CNAME"
      content = "example.com"
      proxied = true
    },
    {
      name    = "api"
      type    = "A"
      content = "192.0.2.1"
      proxied = false
    }
  ]
}
```

## Notes

- TTL of 1 means "auto" for Cloudflare
- `proxied = true` routes traffic through Cloudflare's proxy
- `proxied = false` is a "DNS-only" record

## Requirements

- Provider: `cloudflare` configured with API token
