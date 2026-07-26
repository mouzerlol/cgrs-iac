# Outbound email dispatch infrastructure (ADR 022).
#
# Cloud Tasks owns the outbound-email queue: the API enqueues a task per message
# (OIDC-authenticated as the dispatch SA) targeting POST /internal/email/send, and an
# hourly Cloud Scheduler job hits POST /internal/email/reconcile to recover orphans.

data "google_project" "this" {
  project_id = var.project_id
}

locals {
  labels = { for k, v in var.labels : lower(k) => lower(v) }

  runtime_sa_email = var.runtime_service_account_email != "" ? var.runtime_service_account_email : "${data.google_project.this.number}-compute@developer.gserviceaccount.com"

  cloud_tasks_agent = "service-${data.google_project.this.number}@gcp-sa-cloudtasks.iam.gserviceaccount.com"

  reconcile_audience = var.oidc_audience != "" ? var.oidc_audience : var.reconcile_endpoint_url
}

resource "google_project_service" "cloud_tasks" {
  project            = var.project_id
  service            = "cloudtasks.googleapis.com"
  disable_on_destroy = false
}

# Cloud Scheduler API is also enabled by the cloud-run-keep-warm module; enabling here
# keeps this module self-contained (enable is idempotent; disable_on_destroy=false).
resource "google_project_service" "cloud_scheduler" {
  project            = var.project_id
  service            = "cloudscheduler.googleapis.com"
  disable_on_destroy = false
}

# Service account whose OIDC identity the internal endpoints trust.
resource "google_service_account" "dispatch" {
  project      = var.project_id
  account_id   = var.dispatch_service_account_id
  display_name = "Email Dispatch (Cloud Tasks)"
  description  = "OIDC identity for outbound email Cloud Tasks + reconcile scheduler targeting ${var.service_name}."
}

# The dispatch SA may invoke the (private-by-policy) internal endpoints on the API.
resource "google_cloud_run_v2_service_iam_member" "dispatch_invoker" {
  project  = var.project_id
  location = var.location
  name     = var.service_name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.dispatch.email}"
}

# The Cloud Run runtime SA creates tasks that mint an OIDC token AS the dispatch SA,
# so it must be able to actAs the dispatch SA.
resource "google_service_account_iam_member" "runtime_acts_as_dispatch" {
  service_account_id = google_service_account.dispatch.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${local.runtime_sa_email}"
}

# Cloud Tasks (and Cloud Scheduler) generate the OIDC token via the Cloud Tasks
# service agent, which needs tokenCreator on the dispatch SA.
resource "google_service_account_iam_member" "tasks_agent_token_creator" {
  service_account_id = google_service_account.dispatch.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${local.cloud_tasks_agent}"
}

# The Cloud Run runtime SA creates tasks in this queue, so it needs enqueuer.
resource "google_cloud_tasks_queue_iam_member" "runtime_enqueuer" {
  project  = var.project_id
  location = var.location
  name     = google_cloud_tasks_queue.email_outbound.name
  role     = "roles/cloudtasks.enqueuer"
  member   = "serviceAccount:${local.runtime_sa_email}"
}

resource "google_cloud_tasks_queue" "email_outbound" {
  project  = var.project_id
  location = var.location
  name     = var.queue_id

  retry_config {
    max_attempts  = var.max_attempts
    min_backoff   = var.min_backoff
    max_backoff   = var.max_backoff
    max_doublings = var.max_doublings
  }

  rate_limits {
    max_dispatches_per_second = 10
    max_concurrent_dispatches = 10
  }

  # Per-task dispatch logging to Cloud Logging — effectively free at this volume.
  stackdriver_logging_config {
    sampling_ratio = var.log_sampling_ratio
  }

  depends_on = [google_project_service.cloud_tasks]
}

resource "google_cloud_scheduler_job" "reconcile" {
  project          = var.project_id
  region           = var.location
  name             = "${var.service_name}-email-reconcile"
  description      = "Hourly sweep: re-enqueue orphaned queued outbound emails; fail abandoned ones (ADR 022)."
  schedule         = var.reconcile_cron
  time_zone        = var.time_zone
  attempt_deadline = "320s"

  retry_config {
    retry_count = 1
  }

  http_target {
    http_method = "POST"
    uri         = var.reconcile_endpoint_url

    headers = {
      "Content-Type" = "application/json"
    }

    oidc_token {
      service_account_email = google_service_account.dispatch.email
      audience              = local.reconcile_audience
    }
  }

  depends_on = [google_project_service.cloud_scheduler]
}
