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

# Common tags/labels
tags = {
  Environment = "prod"
  Project     = "cgrs"
  ManagedBy   = "opentofu"
}
