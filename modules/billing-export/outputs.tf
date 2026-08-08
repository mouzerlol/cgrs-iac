output "dataset_id" {
  description = "The BigQuery dataset ID receiving the billing export"
  value       = google_bigquery_dataset.this.dataset_id
}

output "dataset_reference" {
  description = "PROJECT:DATASET reference — the form shown in the Console billing-export picker and used to qualify tables in verification queries"
  value       = "${var.project_id}:${google_bigquery_dataset.this.dataset_id}"
}

output "dataset_location" {
  description = "BigQuery location of the dataset. The billing export can only be linked to a dataset the billing account is allowed to write to in this location."
  value       = google_bigquery_dataset.this.location
}
