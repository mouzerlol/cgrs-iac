environment = "prod"

# GCP — must match the project shown in Cloud Console (name "cgrs" → project id cgrs-492610)
gcp_project_id  = "cgrs-492610"
cloud_run_image = "australia-southeast1-docker.pkg.dev/cgrs-492610/cgrs-api/cgrs-api:latest"

# Browser origins for every bucket's CORS rules. Declared once here; a rule that omits
# allowed_origins inherits this list. Must match the page URL exactly (scheme, host, port).
web_app_origins = [
  "http://localhost:3000",
  "http://127.0.0.1:3000",
  "https://localhost:3000",
  "https://cgrs.co.nz",
  "https://www.cgrs.co.nz",
]

# R2 Bucket Configuration
#
# One community's storage is these entries. A second community is more entries with its own
# names and its own content domain — no new resource types and no module work. That is the
# whole per-tenant cost, and it is why blog isolation is per bucket rather than per key prefix.
r2_buckets = [
  {
    name        = "cgrs-images-prod"
    description = "CGRS website images storage (production)"
    # Presigned PUT/GET from the browser.
    # Note: OPTIONS is not needed in allowed_methods - CORS preflight is handled automatically.
    cors_rules = [
      {
        rule_id         = "cgrs-web-app-origins"
        allowed_methods = ["GET", "PUT", "HEAD"]
        allowed_headers = ["*"]
        expose_headers  = ["ETag", "Content-Length"]
        max_age_seconds = 3600
      }
    ]
  },
  {
    name        = "cgrs-documents-prod"
    description = "CGRS society governance documents — minutes, agendas, financial records (production)"
    # Uploads are proxied server-side through the API (no browser PUT to R2), so CORS is GET/HEAD only.
    # GET/HEAD covers presigned-GET downloads.
    cors_rules = [
      {
        rule_id         = "cgrs-web-app-origins"
        allowed_methods = ["GET", "HEAD"]
        allowed_headers = ["*"]
        expose_headers  = ["ETag", "Content-Length"]
        max_age_seconds = 3600
      }
    ]
    # Reclaim multipart fragments orphaned by failed proxied uploads.
    lifecycle_rules = [
      {
        id                           = "abort-incomplete-multipart-1d"
        prefix                       = ""
        enabled                      = true
        abort_multipart_max_age_days = 1
      }
    ]
  },
  {
    name        = "cgrs-ground-reports-prod"
    description = "CGRS ground-report images — location-tagged photo reports of the development (production)"
    # Uploads are proxied server-side through the API (no browser PUT to R2); the member
    # reel loads images via presigned GET, so CORS is GET/HEAD only.
    cors_rules = [
      {
        rule_id         = "cgrs-web-app-origins"
        allowed_methods = ["GET", "HEAD"]
        allowed_headers = ["*"]
        expose_headers  = ["ETag", "Content-Length"]
        max_age_seconds = 3600
      }
    ]
    # NOTE: 180-day object-expiration lifecycle is intentionally out of scope for now
    # (add-ground-report §4.3). The API's member query still excludes >180-day reports.
  },
  {
    name        = "cgrs-blog-prod"
    description = "CGRS published blog artifacts — manifest, post bodies, published imagery (production)"
    # WORLD-READABLE BY DESIGN. Binding the custom domain is what opens it; nothing
    # unpublished may ever be written here. Drafts and source live in cgrs-blog-src-prod.
    custom_domain = {
      name = "content.cgrs.co.nz"
      zone = "cgrs.co.nz"
    }
    # Reads only. Every write is server-side through the API, so no browser ever issues a PUT.
    cors_rules = [
      {
        rule_id         = "cgrs-web-app-origins"
        allowed_methods = ["GET", "HEAD"]
        allowed_headers = ["*"]
        expose_headers  = ["ETag", "Content-Length"]
        max_age_seconds = 3600
      }
    ]
    lifecycle_rules = [
      {
        id                           = "abort-incomplete-multipart-1d"
        prefix                       = ""
        enabled                      = true
        abort_multipart_max_age_days = 1
      }
    ]
  },
  {
    name        = "cgrs-blog-src-prod"
    description = "CGRS blog working store — source markdown, revision archives, unpublished assets (production)"
    # Private. No custom domain, no public access, and no CORS because no browser addresses it.
    lifecycle_rules = [
      {
        id                           = "abort-incomplete-multipart-1d"
        prefix                       = ""
        enabled                      = true
        abort_multipart_max_age_days = 1
      }
    ]
  }
]

# Artifact Registry
artifact_registry_enabled       = true
artifact_registry_repository_id = "cgrs-api"
artifact_registry_max_versions  = 5

# Cloud Run
cloud_run_enabled       = true
cloud_run_service_name  = "cgrs-api"
cloud_run_min_instances = 0
cloud_run_max_instances = 2
cloud_run_cpu           = "1"
cloud_run_memory        = "512Mi"
# Browser Origins for credentialed CORS (must match the page URL exactly, not the API host). Include 127.0.0.1 for local UI against prod API.
cloud_run_cors_origins = "https://www.cgrs.co.nz,https://cgrs.co.nz,http://localhost:3000,http://127.0.0.1:3000"

# Keep-warm — a Cloud Scheduler GET /health every 5 min during NZ waking hours keeps one
# instance resident. min_instances stays 0: under request-based billing a resident-but-idle
# instance is NOT billed, whereas min_instances=1 billed ~1.9M instance-seconds/month (10.6x
# the free-tier CPU allowance) for something measured 97% idle. Best-effort by design — Cloud
# Run's ~15 min idle retention is documented but not guaranteed; 5 min gives a 3x margin.
# Set cloud_run_scheduler_enabled = false to disable during an incident; to force warmth
# immediately use `gcloud run services update cgrs-api --min-instances=1` and revert after.
cloud_run_scheduler_enabled      = true
cloud_run_ping_cron              = "*/5 6-22 * * *"
cloud_run_warm_window_start_hour = 6
cloud_run_warm_window_end_hour   = 23
cloud_run_schedule_timezone      = "Pacific/Auckland"

# Outbound email dispatch via Cloud Tasks (ADR 022). base_url is the API's stable Cloud
# Run v2 service URL (same value the frontend uses as NEXT_PUBLIC_API_URL). Provisions the
# queue + reconcile scheduler and turns on EMAIL_DISPATCH_VIA_CLOUD_TASKS in the API.
email_dispatch_enabled  = true
email_dispatch_base_url = "https://cgrs-api-154910431334.australia-southeast1.run.app"
# Reconcile twice daily inside the Cloud Run warm window (07:00 + 19:00 NZ). Each sweep
# forces a >=5-min Neon compute wake (Free tier autosuspend is fixed at 5 min, no override),
# so hourly sweeps burned ~10 standalone compute-hrs/mo for a low-volume queue. Twice-daily
# keeps orphan-recovery latency <=12h — well under the 24h fail_after horizon — for near-zero
# Neon cost. Both fires land in the warm window so they add no Cloud Run cold start.
email_reconcile_cron = "0 7,19 * * *"

# BigQuery billing export — makes a cost regression queryable per SKU instead of reconstructed
# from Cloud Monitoring. Tofu creates the destination dataset ONLY; billing account
# 01025D-63750F-AAE0CD must be linked to it by hand in the Console as a "Standard usage cost"
# export (Console-only — no Terraform resource or gcloud command exists). Until that link is
# made the dataset stays empty. Steps + verification query: environments/prod/README.md.
# Cost is ~$0: single-digit MB/month against 10 GiB/mo free storage and 1 TiB/mo free query.
billing_export_enabled    = true
billing_export_dataset_id = "billing_export"

# Common tags/labels
tags = {
  Environment = "prod"
  Project     = "cgrs"
  ManagedBy   = "opentofu"
}
