environment = "prod"

# GCP — must match the project shown in Cloud Console (name "cgrs" → project id cgrs-492610)
gcp_project_id = "cgrs-492610"
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
        rule_id         = "cgrs-web-app-origins"
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
  }
]

# Artifact Registry
artifact_registry_enabled       = true
artifact_registry_repository_id = "cgrs-api"
artifact_registry_max_versions  = 5

# Cloud Run
cloud_run_enabled      = true
cloud_run_service_name = "cgrs-api"
cloud_run_min_instances = 0
cloud_run_max_instances = 2
cloud_run_cpu          = "1"
cloud_run_memory       = "512Mi"
cloud_run_cors_origins = "https://www.cgrs.co.nz,https://cgrs.co.nz,http://localhost:3000"

# Common tags/labels
tags = {
  Environment = "prod"
  Project     = "cgrs"
  ManagedBy   = "opentofu"
}
