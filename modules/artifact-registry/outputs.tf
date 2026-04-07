output "repository_id" {
  description = "The repository ID"
  value       = google_artifact_registry_repository.this.repository_id
}

output "repository_name" {
  description = "Full resource name of the repository"
  value       = google_artifact_registry_repository.this.name
}

output "repository_url" {
  description = "Docker registry URL for push/pull (REGION-docker.pkg.dev/PROJECT/REPO)"
  value       = "${var.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.this.repository_id}"
}
