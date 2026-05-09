output "service_url" {
  description = "The URL of the Cloud Run service"
  value       = google_cloud_run_v2_service.this.uri
}

output "service_name" {
  description = "The name of the Cloud Run service"
  value       = google_cloud_run_v2_service.this.name
}

output "location" {
  description = "The region of the Cloud Run service"
  value       = google_cloud_run_v2_service.this.location
}

output "latest_revision" {
  description = "The latest revision of the service"
  value       = google_cloud_run_v2_service.this.latest_ready_revision
}
