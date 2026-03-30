environment = "prod"

# R2 Bucket Configuration
r2_buckets = [
  {
    name        = "cgrs-images-prod"
    description = "CGRS website images storage (production)"
    # Presigned PUT/GET from the browser: origins must match the page URL exactly (scheme, host, port).
    # Include OPTIONS so preflight succeeds; use * for headers if the browser sends Content-Length etc.
    cors_rules = [
      {
        rule_id         = "cgrs-web-app-origins"
        allowed_origins = ["http://localhost:3000", "http://127.0.0.1:3000", "https://localhost:3000", "https://cgrs.co.nz"]
        allowed_methods = ["GET", "PUT", "HEAD", "OPTIONS"]
        allowed_headers   = ["*"]
        expose_headers    = ["ETag", "Content-Length"]
        max_age_seconds   = 3600
      }
    ]
  }
]

# Common tags
tags = {
  Environment = "prod"
  Project     = "cgrs"
  ManagedBy   = "opentofu"
}
