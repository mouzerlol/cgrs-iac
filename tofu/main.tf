terraform {
  required_version = ">= 1.10"

  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.67"
    }
    cloudflare = {
      source  = "hashicorp/cloudflare"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  alias = "backend"

  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
  region     = var.aws_region

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3 = var.aws_endpoint
  }
}

# cloudflare_r2_bucket calls api.cloudflare.com — needs an API token (not R2 S3 access keys).
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

module "r2_buckets" {
  source = "../modules/r2-bucket"

  for_each = { for bucket in var.r2_buckets : bucket.name => bucket }

  enabled         = true
  bucket_name     = each.value.name
  account_id      = var.cloudflare_account_id
  cors_rules      = try(each.value.cors_rules, [])
}