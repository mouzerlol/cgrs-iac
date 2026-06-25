output "dispatch_service_account_email" {
  description = "Service account email the internal endpoints verify OIDC tokens against."
  value       = google_service_account.dispatch.email
}

output "queue_name" {
  description = "Full resource name of the Cloud Tasks queue."
  value       = google_cloud_tasks_queue.email_outbound.name
}

output "queue_id" {
  description = "Short id of the Cloud Tasks queue."
  value       = google_cloud_tasks_queue.email_outbound.name
}

output "reconcile_job_name" {
  description = "Name of the reconcile Cloud Scheduler job."
  value       = google_cloud_scheduler_job.reconcile.name
}
