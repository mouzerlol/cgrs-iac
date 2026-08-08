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

        # Extra CPU during container startup only. Measured cold start was ~20-27s
        # (startup_latencies mean ~22.8s), dominated by CPU-bound Python imports of the
        # FastAPI route tree on a single vCPU. Boost applies to the startup window only,
        # so steady-state cost is unchanged; it shortens the window that IS billed.
        startup_cpu_boost = var.startup_cpu_boost
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

      # Startup probe — gates traffic until the app answers /health. (It no longer waits on
      # alembic: migrations were taken out of the boot path, see `decouple-migrations-harden-cold-start`.)
      #
      # The probe CADENCE, not the app, was the binding constraint on measured cold start.
      # Production measurement: the app is ready at ~6.9 s but `startup_latencies` read
      # 10,052 ms — because probes fired at t=5 s (fail) and t=10 s (pass). The extra ~3.1 s
      # was pure probe granularity. At 2 s/2 s the probes fire at t=2/4/6/8, so the same 6.9 s
      # boot is admitted at ~8 s. Granularity cost drops from <=5 s to <=2 s.
      #
      # failure_threshold 10 -> 25 deliberately: the budget is
      #   initial_delay + period * (failure_threshold - 1) + timeout
      # so at 2/2 a threshold of 10 would give 2 + 18 + 1 = 21 s — comfortably over the ~7 s
      # ready time (3x), but BELOW the 22.8 s cold start this service had before
      # `reduce-api-cold-start`. That turns any future import-time regression from "slow" into
      # "revision never becomes ready". 25 gives 2 + 48 + 1 = 51 s, holding the previous ~53 s
      # deploy-failure envelope (5 + 45 + 3) while making the success path faster. Extra
      # attempts are free — probing stops at the first success.
      #
      # timeout_seconds 3 -> 1: Cloud Run requires timeout_seconds < period_seconds, so 3 is
      # invalid once period is 2. 1 s is ample — /health is DB-free and returns in ms; before
      # uvicorn binds the probe fails on connection refused, not on timeout.
      startup_probe {
        http_get {
          path = "/health"
          port = var.port
        }
        initial_delay_seconds = 2
        period_seconds        = 2
        failure_threshold     = 25
        timeout_seconds       = 1
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
      # min_instance_count is deliberately NOT ignored. Nothing mutates it at runtime any more
      # (the keep-warm module pings /health instead of PATCHing scaling), so OpenTofu owns it
      # and any accidental re-introduction of a non-zero value shows up as drift in `make plan`.
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
