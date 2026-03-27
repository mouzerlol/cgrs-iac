environment = "prod"

# R2 Bucket Configuration
r2_buckets = [
  {
    name        = "cgrs-images-prod"
    description = "CGRS website images storage (production)"
    tags = {
      Environment = "prod"
      Project     = "cgrs"
    }
  }
]

# Cloudflare DNS Records
dns_records = [
  {
    name    = "images"
    type    = "CNAME"
    content = "cgrs-images-prod.r2.dev"
    proxied = true
  }
]

# Common tags
tags = {
  Environment = "prod"
  Project     = "cgrs"
  ManagedBy   = "opentofu"
}
