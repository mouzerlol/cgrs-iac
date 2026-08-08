# BigQuery destination for the Cloud Billing "Standard usage cost" export, so per-SKU spend is
# queryable directly instead of being reconstructed from Cloud Monitoring usage metrics.
#
# IMPORTANT — THIS MODULE ONLY CREATES THE RECEIVER.
# Google provides no Terraform resource, no gcloud command and no stable API for enabling
# Cloud Billing export to BigQuery; linking a billing account to a dataset is Console-only
# (see terraform-provider-google#4848). So `tofu apply` alone leaves the export INERT: the
# dataset exists and stays empty until an operator does the one-time manual link at
#   Billing -> <billing account> -> Billing export -> BigQuery export -> Standard usage cost
# and points it at this dataset. Steps and the row-arrival verification query live in
# `environments/prod/README.md`. If the documented query returns no rows, that manual step is
# the missing piece — not this module.
#
# Standard usage cost, not Detailed: Standard attributes spend to a SKU (the whole requirement)
# while Detailed emits per-resource rows that grow substantially faster.
#
# See openspec change `ping-to-warm-cloud-run`.

# Enable the BigQuery API — required before creating datasets. disable_on_destroy = false
# prevents the API being disabled if this module is removed, which would break any other
# BigQuery usage in the project.
resource "google_project_service" "bigquery" {
  project            = var.project_id
  service            = "bigquery.googleapis.com"
  disable_on_destroy = false
}

resource "google_bigquery_dataset" "this" {
  project     = var.project_id
  dataset_id  = var.dataset_id
  location    = var.location
  description = var.description

  # No default_table_expiration_ms and no default_partition_expiration_ms on purpose: billing
  # history is the point of the export, and expiring it would silently destroy the baseline a
  # future cost regression is measured against. Cost of keeping it is ~$0 — the export is
  # single-digit MB/month against a 10 GiB/month free active-storage allowance.

  # Refuse to drop the dataset while it still holds exported tables. `tofu destroy` on a
  # populated export should fail loudly rather than delete billing history.
  delete_contents_on_destroy = false

  # GCP labels must be lowercase — normalize keys from shared tags map
  labels = { for k, v in var.labels : lower(k) => lower(v) }

  depends_on = [google_project_service.bigquery]
}
