output "keep_warm_job_name" {
  description = "Name of the keep-warm Cloud Scheduler job"
  value       = google_cloud_scheduler_job.keep_warm.name
}

output "keep_warm_uri" {
  description = "URL the keep-warm job pings"
  value       = google_cloud_scheduler_job.keep_warm.http_target[0].uri
}

# The frontend's cold-start banner needs to know when the API is cold. These output NAMES are
# deliberately unchanged from when this module scaled min_instance_count, because a deploy step
# pipes them into NEXT_PUBLIC_SLEEP_WINDOW_START_HOUR / NEXT_PUBLIC_SLEEP_WINDOW_END_HOUR.
# Renaming them to "warm window" would force a coordinated frontend change for zero functional
# gain — see `ping-to-warm-cloud-run` task 8.2. The values now come from explicit window
# variables rather than being parsed out of the retired scale-up/scale-down crons.
output "scale_up_hour" {
  description = "Hour of day (in time_zone) the API becomes warm (kept-warm window opens)"
  value       = var.warm_window_start_hour
}

output "scale_down_hour" {
  description = "Hour of day (in time_zone) the API goes cold (kept-warm window closes)"
  value       = var.warm_window_end_hour
}

output "schedule_time_zone" {
  description = "IANA time zone the keep-warm cron evaluates against"
  value       = var.time_zone
}
