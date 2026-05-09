# Enable the Cloud Run API
resource "google_project_service" "run" {
  project            = var.project_id
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_cloud_run_v2_service" "this" {
  project  = var.project_id
  location = var.location
  name     = var.service_name

  # GCP labels must be lowercase
  labels = { for k, v in var.labels : lower(k) => lower(v) }

  template {
    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    timeout = "${var.timeout}s"

    containers {
      image = var.image

      ports {
        container_port = var.port
      }

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
        cpu_idle = true # CPU throttled when not processing requests (cost saving)
      }

      # Non-sensitive environment variables
      dynamic "env" {
        for_each = var.env_vars
        content {
          name  = env.key
          value = env.value
        }
      }

      # Sensitive environment variables (same mechanism, separated for clarity)
      dynamic "env" {
        for_each = var.secret_env_vars
        content {
          name  = env.key
          value = env.value
        }
      }

      # Startup probe — gives alembic migrations time to complete before accepting traffic
      startup_probe {
        http_get {
          path = "/health"
          port = var.port
        }
        initial_delay_seconds = 5
        period_seconds        = 5
        failure_threshold     = 10 # 5 + (5 * 10) = 55 seconds max startup time
        timeout_seconds       = 3
      }

      # Liveness probe — restart if unhealthy
      liveness_probe {
        http_get {
          path = "/health"
          port = var.port
        }
        period_seconds    = 30
        failure_threshold = 3
        timeout_seconds   = 3
      }
    }
  }

  # Route all traffic to the latest revision
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  deletion_protection = false

  depends_on = [google_project_service.run]

  lifecycle {
    ignore_changes = [
      # Allow image updates via `gcloud run deploy` or Makefile without IaC drift
      template[0].containers[0].image,
      # Owned at runtime by the cloud-run-scheduler module (Cloud Scheduler PATCHes this twice daily).
      # var.min_instances seeds the initial value on first apply only.
      template[0].scaling[0].min_instance_count,
    ]
  }
}

# Allow unauthenticated access (public API)
resource "google_cloud_run_v2_service_iam_member" "public" {
  count = var.allow_unauthenticated ? 1 : 0

  project  = var.project_id
  location = var.location
  name     = google_cloud_run_v2_service.this.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
