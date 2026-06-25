environment = "prod"

# GCP — must match the project shown in Cloud Console (name "cgrs" → project id cgrs-492610)
gcp_project_id  = "cgrs-492610"
cloud_run_image = "australia-southeast1-docker.pkg.dev/cgrs-492610/cgrs-api/cgrs-api:latest"

# R2 Bucket Configuration
r2_buckets = [
  {
    name        = "cgrs-images-prod"
    description = "CGRS website images storage (production)"
    # Presigned PUT/GET from the browser: origins must match the page URL exactly (scheme, host, port).
    # Note: OPTIONS is not needed in allowed_methods - CORS preflight is handled automatically.
    cors_rules = [
      {
        rule_id = "cgrs-web-app-origins"
        allowed_origins = [
          "http://localhost:3000",
          "http://127.0.0.1:3000",
          "https://localhost:3000",
          "https://cgrs.co.nz",
          "https://www.cgrs.co.nz",
        ]
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
    # GET/HEAD covers presigned-GET downloads. Origins mirror cgrs-images-prod — keep this list in sync.
    cors_rules = [
      {
        rule_id = "cgrs-web-app-origins"
        allowed_origins = [
          "http://localhost:3000",
          "http://127.0.0.1:3000",
          "https://localhost:3000",
          "https://cgrs.co.nz",
          "https://www.cgrs.co.nz",
        ]
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
    # reel loads images via presigned GET, so CORS is GET/HEAD only. Origins mirror the
    # other buckets — keep this list in sync.
    cors_rules = [
      {
        rule_id = "cgrs-web-app-origins"
        allowed_origins = [
          "http://localhost:3000",
          "http://127.0.0.1:3000",
          "https://localhost:3000",
          "https://cgrs.co.nz",
          "https://www.cgrs.co.nz",
        ]
        allowed_methods = ["GET", "HEAD"]
        allowed_headers = ["*"]
        expose_headers  = ["ETag", "Content-Length"]
        max_age_seconds = 3600
      }
    ]
    # NOTE: 180-day object-expiration lifecycle is intentionally out of scope for now
    # (add-ground-report §4.3). The API's member query still excludes >180-day reports.
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

# Scheduled scaling — keep one warm instance during NZ waking hours, scale to zero overnight.
# Set cloud_run_scheduler_enabled = false to disable during incidents (operator owns min_instances thereafter).
cloud_run_scheduler_enabled  = true
cloud_run_warm_min_instances = 1
cloud_run_scale_up_cron      = "0 6 * * *"
cloud_run_scale_down_cron    = "0 23 * * *"
cloud_run_schedule_timezone  = "Pacific/Auckland"

# Outbound email dispatch via Cloud Tasks (ADR 022). base_url is the API's stable Cloud
# Run v2 service URL (same value the frontend uses as NEXT_PUBLIC_API_URL). Provisions the
# queue + reconcile scheduler and turns on EMAIL_DISPATCH_VIA_CLOUD_TASKS in the API.
email_dispatch_enabled  = true
email_dispatch_base_url = "https://cgrs-api-154910431334.australia-southeast1.run.app"
# Reconcile only during the Cloud Run warm window (06:00–23:00 NZ). Neon Free fixes
# autosuspend at 5 min (no override), so an overnight sweep would cold-start Cloud Run
# AND bill a 5-min Neon wake every hour for nothing. Warm-window-only adds zero extra
# wakes; orphaned mail just waits until the next morning.
email_reconcile_cron = "0 6-23 * * *"

# Common tags/labels
tags = {
  Environment = "prod"
  Project     = "cgrs"
  ManagedBy   = "opentofu"
}
