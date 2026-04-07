# Enable the Artifact Registry API — required before creating repositories.
# disable_on_destroy = false prevents the API from being disabled if this module is removed,
# which would orphan any manually-created repositories outside this module.
resource "google_project_service" "artifactregistry" {
  project            = var.project_id
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "this" {
  project       = var.project_id
  location      = var.location
  repository_id = var.repository_id
  description   = var.description
  format        = var.format

  depends_on = [google_project_service.artifactregistry]

  docker_config {
    immutable_tags = var.immutable_tags
  }

  # GCP labels must be lowercase — normalize keys from shared tags map
  labels = { for k, v in var.labels : lower(k) => lower(v) }

  # Cleanup policy: retain only the N most recent versions per package.
  # Keeps storage bounded within free-tier limits (~0.5 GB).
  dynamic "cleanup_policies" {
    for_each = var.cleanup_max_versions > 0 ? [1] : []
    content {
      id     = "keep-recent-versions"
      action = "KEEP"
      most_recent_versions {
        package_name_prefixes = []
        keep_count            = var.cleanup_max_versions
      }
    }
  }

  # Delete anything not matched by a KEEP policy
  dynamic "cleanup_policies" {
    for_each = var.cleanup_max_versions > 0 ? [1] : []
    content {
      id     = "delete-old-versions"
      action = "DELETE"
      condition {
        older_than = "2592000s" # 30 days
      }
    }
  }

  cleanup_policy_dry_run = false
}
