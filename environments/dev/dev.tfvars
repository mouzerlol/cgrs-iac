environment = "dev"

# R2 Bucket Configuration
r2_buckets = [
  {
    name        = "cgrs-images-dev"
    description = "CGRS website images storage (dev)"
    tags = {
      Environment = "dev"
      Project     = "cgrs"
    }
  }
]

# Cloudflare DNS Records
dns_records = [
  {
    name    = "dev"
    type    = "CNAME"
    content = "cgrs-images-dev.r2.dev"
    proxied = false
  }
]

# Common tags
tags = {
  Environment = "dev"
  Project     = "cgrs"
  ManagedBy   = "opentofu"
}
