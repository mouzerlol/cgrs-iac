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

# The frontend's cold-start banner needs to know when the API sleeps. These
# outputs surface the hour fields of the cron expressions (assumed shape
# "M H * * *") so a CI/deploy step can pipe them into
# NEXT_PUBLIC_SLEEP_WINDOW_START_HOUR / NEXT_PUBLIC_SLEEP_WINDOW_END_HOUR. The
# IaC stays the single source of truth.
output "scale_up_hour" {
  description = "Hour of day (Pacific/Auckland) at which the API scales up to min=1"
  value       = tonumber(split(" ", var.scale_up_cron)[1])
}

output "scale_down_hour" {
  description = "Hour of day (Pacific/Auckland) at which the API scales down to min=0"
  value       = tonumber(split(" ", var.scale_down_cron)[1])
}

output "schedule_time_zone" {
  description = "IANA time zone the scale-up/down crons evaluate against"
  value       = var.time_zone
}
