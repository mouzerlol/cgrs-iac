# add-cloud-run-scheduled-scaling

Schedule Cloud Run cgrs-api to keep min=1 during NZ business hours (06:00-22:59) and scale to 0 overnight, via Cloud Scheduler PATCHing the Admin API.
