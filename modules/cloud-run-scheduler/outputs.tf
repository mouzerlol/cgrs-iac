output "service_account_email" {
  description = "Email of the service account used by the scheduler jobs"
  value       = google_service_account.scheduler.email
}

output "scale_up_job_name" {
  description = "Name of the scale-up Cloud Scheduler job"
  value       = google_cloud_scheduler_job.scale_up.name
}

output "scale_down_job_name" {
  description = "Name of the scale-down Cloud Scheduler job"
  value       = google_cloud_scheduler_job.scale_down.name
}
