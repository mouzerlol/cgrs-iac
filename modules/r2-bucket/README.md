# R2 Bucket Module

Creates one Cloudflare R2 bucket and, optionally, its CORS rules, lifecycle rules, public
access, and custom domain. Every optional piece is a count-guarded resource, so a bucket
declared with none of them results in exactly one resource and is private.

Buckets are managed through `api.cloudflare.com` with the `cloudflare` provider and a
Cloudflare API token — not through the S3-compatible endpoint. The S3 credentials the
application uses are created out of band in the dashboard and never appear in state.

## Usage

```hcl
# Private bucket, reached only by the API with S3 credentials.
module "documents" {
  source = "../modules/r2-bucket"

  bucket_name = "cgrs-documents-prod"
  account_id  = var.cloudflare_account_id

  cors_rules = [
    {
      rule_id         = "cgrs-web-app-origins"
      allowed_origins = ["https://cgrs.co.nz"]
      allowed_methods = ["GET", "HEAD"]
    }
  ]

  lifecycle_rules = [
    {
      id                           = "abort-incomplete-multipart-1d"
      abort_multipart_max_age_days = 1
    }
  ]
}

# Publicly readable bucket on a hostname the society owns.
module "blog" {
  source = "../modules/r2-bucket"

  bucket_name = "cgrs-blog-prod"
  account_id  = var.cloudflare_account_id

  custom_domain = {
    name    = "content.cgrs.co.nz"
    zone_id = data.cloudflare_zone.primary.id
  }
}
```

## Inputs

| Name | Type | Default | Effect |
| --- | --- | --- | --- |
| `bucket_name` | `string` | — | Bucket name. |
| `account_id` | `string` | — | Cloudflare account the bucket belongs to. |
| `cors_rules` | `list(object)` | `[]` | Empty skips `cloudflare_r2_bucket_cors`. |
| `lifecycle_rules` | `list(object)` | `[]` | Empty skips `cloudflare_r2_bucket_lifecycle`. `abort_multipart_max_age_days` is given in days and converted to seconds. |
| `custom_domain` | `object({ name, zone_id, min_tls })` | `null` | Null skips `cloudflare_r2_custom_domain`. |
| `public_access_enabled` | `bool` | `false` | `true` creates `cloudflare_r2_managed_domain` (the `r2.dev` hostname). |
| `enabled`, `website_enabled`, `routing_rules` | — | — | Declared but unused by any current resource. |

## Public access

A bucket is private unless something makes it public, and two inputs can:

- **`custom_domain`** binds a hostname and is the supported way. Objects become readable
  without credentials at `https://<name>/<key>` and are cached at Cloudflare's edge.
  Cloudflare creates the DNS record as part of the binding, so there is no separate
  `cloudflare_dns_record` here that could drift out of step with it. `zone_id` must be the
  zone the hostname sits in, and the Cloudflare API token needs Zone read and DNS edit rights
  on that zone — an R2-only token is not enough. The module takes the id rather than a zone
  name on purpose: resolving a name is the caller's job, so the module needs no zone
  permissions of its own and stays usable with an id from any source. The root configuration
  resolves it with `data "cloudflare_zone"`.
- **`public_access_enabled`** turns on the account-specific `r2.dev` hostname instead. It is
  off by default and this estate does not use it: it embeds the account id in every URL and
  is rate-limited for production traffic.

Public access in R2 is bucket-wide. There is no policy expressing "only these prefixes are
public", so content that must not be served has to live in a different bucket.

## Outputs

| Name | Value |
| --- | --- |
| `id` | Bucket id. |
| `cors_configured` | Whether a CORS resource was applied. |
| `public_access_enabled` | Whether the bucket is readable without credentials, by either mechanism. |
| `public_hostname` | The bound hostname, or `null` when the bucket is private. |

## Requirements

- Provider: `cloudflare` `~> 5.0`
- A Cloudflare API token with R2 edit rights, plus DNS edit on the zone if `custom_domain` is used
