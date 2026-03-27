resource "aws_s3_bucket" "this" {
  count = var.enabled ? 1 : 0

  bucket = var.bucket_name

  tags = merge(
    {
      Name = var.bucket_name
    },
    var.tags
  )
}

resource "aws_s3_bucket_versioning" "this" {
  count = var.enabled ? 1 : 0

  bucket = aws_s3_bucket.this[0].id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  count = var.enabled ? 1 : 0

  bucket = aws_s3_bucket.this[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  count = var.enabled ? 1 : 0

  bucket = aws_s3_bucket.this[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_website_configuration" "this" {
  count = var.enabled && var.website_enabled ? 1 : 0

  bucket = aws_s3_bucket.this[0].id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }

  routing_rules = var.routing_rules
}
