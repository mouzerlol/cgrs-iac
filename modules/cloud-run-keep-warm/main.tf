# Keep cgrs-api responsive during NZ waking hours WITHOUT paying for idle instances.
#
# This module used to PATCH `min_instance_count` to 1 for the warm window. That cost
# ~1,900,000 billable instance-seconds/month — 10.6x the Cloud Run free-tier CPU allowance
# (180,000 vCPU-s) — of which 97% was measured idle (instance_count: 0.960 idle vs 0.026
# active). australia-southeast1 is a Tier 2 region, so min-instance rates are 1.4x Tier 1
# while the free tier is granted as a spending-based discount valued at Tier 1 rates.
#
# Under request-based billing (`cpu_idle = true`) an instance is charged only while it
# processes a request, plus start and shutdown — a resident-but-idle instance at
# `min_instance_count = 0` is NOT billed. Cloud Run also "might keep instances idle for a
# period of time after they finish handling requests (up to 15 minutes)". So periodic cheap
# traffic keeps an instance resident for ~0.35% of the free allowance instead of 1,056% of it.
#
# The retention window is documented but NOT guaranteed ("might"), so this is best-effort by
# construction. A 5-minute ping against a ~15-minute retention budget is a 3x margin. If the
# instance is reclaimed anyway, users pay a container cold start (~10s as measured on revision
# cgrs-api-00217-92f) — verify with startup_latencies after cutover and roll back with
# `gcloud run services update cgrs-api --min-instances=1` if startups climb toward the ping count.
#
# See openspec change `ping-to-warm-cloud-run`.

resource "google_project_service" "scheduler" {
  project            = var.project_id
  service            = "cloudscheduler.googleapis.com"
  disable_on_destroy = false
}

# A plain GET against a public endpoint needs no IAM at all. The previous PATCH approach
# required roles/run.developer on the service AND roles/iam.serviceAccountUser on the runtime
# service account (for actAs); both are gone, along with the dedicated service account.
# The header keeps pings distinguishable from organic traffic in logs and analytics.
resource "google_cloud_scheduler_job" "keep_warm" {
  project     = var.project_id
  region      = var.location
  name        = "${var.service_name}-keep-warm"
  description = "GET ${var.health_path} on ${var.service_name} every 5 min during the warm window, to keep an instance resident without paying min-instance idle billing."
  schedule    = var.ping_cron
  time_zone   = var.time_zone

  # Short deadline and a single retry: a missed ping is harmless (the next one is 5 min away)
  # and a hung request must not hold a scheduler slot open.
  attempt_deadline = "30s"

  retry_config {
    retry_count = 1
  }

  http_target {
    http_method = "GET"
    uri         = "${var.service_url}${var.health_path}"

    headers = {
      "X-CGRS-Keepalive" = "1"
      "User-Agent"       = "cgrs-keep-warm/1.0"
    }
  }

  depends_on = [google_project_service.scheduler]
}
