data "google_project" "this" {
  project_id = var.project_id
}

locals {
  service_uri = "https://run.googleapis.com/v2/projects/${var.project_id}/locations/${var.location}/services/${var.service_name}"
  patch_url   = "${local.service_uri}?updateMask=template.scaling.minInstanceCount"

  scale_up_body   = jsonencode({ template = { scaling = { minInstanceCount = var.warm_min_instances } } })
  scale_down_body = jsonencode({ template = { scaling = { minInstanceCount = 0 } } })

  labels = { for k, v in var.labels : lower(k) => lower(v) }

  # Cloud Run v2 PATCH requires the caller to have actAs on the service's runtime SA.
  # Default Compute Engine SA is used when no custom runtime SA is configured on the service.
  runtime_sa_email = var.runtime_service_account_email != "" ? var.runtime_service_account_email : "${data.google_project.this.number}-compute@developer.gserviceaccount.com"
}

resource "google_project_service" "scheduler" {
  project            = var.project_id
  service            = "cloudscheduler.googleapis.com"
  disable_on_destroy = false
}

resource "google_service_account" "scheduler" {
  project      = var.project_id
  account_id   = var.service_account_id
  display_name = "Cloud Run Scheduled Scaling"
  description  = "Used by Cloud Scheduler to PATCH min_instance_count on ${var.service_name}."
}

# Scope IAM to the target service, not the project, so the SA cannot mutate other Cloud Run services.
resource "google_cloud_run_v2_service_iam_member" "scheduler_developer" {
  project  = var.project_id
  location = var.location
  name     = var.service_name
  role     = "roles/run.developer"
  member   = "serviceAccount:${google_service_account.scheduler.email}"
}

# Required for Cloud Run v2 services.patch: the caller must be able to actAs the service's runtime SA.
# Without this, PATCH returns 403 PERMISSION_DENIED with "Permission 'iam.serviceaccounts.actAs' denied".
resource "google_service_account_iam_member" "scheduler_act_as_runtime" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/${local.runtime_sa_email}"
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.scheduler.email}"
}

resource "google_cloud_scheduler_job" "scale_up" {
  project          = var.project_id
  region           = var.location
  name             = "${var.service_name}-scale-up"
  description      = "Set min_instance_count=${var.warm_min_instances} on ${var.service_name} at the start of the warm window."
  schedule         = var.scale_up_cron
  time_zone        = var.time_zone
  attempt_deadline = "60s"

  retry_config {
    retry_count = 3
  }

  http_target {
    http_method = "PATCH"
    uri         = local.patch_url
    body        = base64encode(local.scale_up_body)

    headers = {
      "Content-Type" = "application/json"
    }

    # Cloud Run Admin API is a Google API — must use OAuth, not OIDC.
    oauth_token {
      service_account_email = google_service_account.scheduler.email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }

  depends_on = [
    google_project_service.scheduler,
    google_cloud_run_v2_service_iam_member.scheduler_developer,
    google_service_account_iam_member.scheduler_act_as_runtime,
  ]
}

resource "google_cloud_scheduler_job" "scale_down" {
  project          = var.project_id
  region           = var.location
  name             = "${var.service_name}-scale-down"
  description      = "Set min_instance_count=0 on ${var.service_name} at the end of the warm window."
  schedule         = var.scale_down_cron
  time_zone        = var.time_zone
  attempt_deadline = "60s"

  retry_config {
    retry_count = 3
  }

  http_target {
    http_method = "PATCH"
    uri         = local.patch_url
    body        = base64encode(local.scale_down_body)

    headers = {
      "Content-Type" = "application/json"
    }

    oauth_token {
      service_account_email = google_service_account.scheduler.email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }

  depends_on = [
    google_project_service.scheduler,
    google_cloud_run_v2_service_iam_member.scheduler_developer,
    google_service_account_iam_member.scheduler_act_as_runtime,
  ]
}
