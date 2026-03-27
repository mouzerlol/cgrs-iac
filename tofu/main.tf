terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  alias      = "r2"
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
  endpoint   = var.aws_endpoint
  region     = var.aws_region

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  s3_use_path_style           = true
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

locals {
  common_tags = merge(
    {
      Environment = var.environment
      Project     = "cgrs"
      ManagedBy   = "opentofu"
    },
    var.tags
  )
}

module "r2_buckets" {
  source = "../modules/r2-bucket"

  for_each = { for bucket in var.r2_buckets : bucket.name => bucket }

  enabled            = true
  bucket_name        = each.value.name
  versioning_enabled = true
  website_enabled    = lookup(each.value, "website_enabled", false)
  tags               = merge(local.common_tags, lookup(each.value, "tags", {}))
}

module "dns_records" {
  source = "../modules/cloudflare-dns"

  enabled   = true
  zone_id   = var.cloudflare_zone_id
  records   = var.dns_records
}
