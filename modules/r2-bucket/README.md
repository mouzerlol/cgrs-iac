# R2 Bucket Module

This module creates an R2 bucket using the AWS S3-compatible API.

## Usage

```hcl
module "r2_bucket" {
  source = "../../modules/r2-bucket"

  bucket_name       = "my-bucket"
  versioning_enabled = true
  website_enabled   = true

  tags = {
    Environment = "dev"
    Project     = "cgrs"
  }
}
```

## Notes

- R2 buckets use the AWS S3 provider with the R2 endpoint
- Public access is blocked by default for security
- Server-side encryption with AES256 is enabled by default
- Versioning is optional but recommended for state files

## Requirements

- Provider: `aws` with R2 endpoint configuration
