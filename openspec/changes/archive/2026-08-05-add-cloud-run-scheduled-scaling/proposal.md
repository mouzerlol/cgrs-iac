> **SUPERSEDED — archived 2026-08-05. Replaced by `ping-to-warm-cloud-run`** (root openspec
> instance: `openspec/changes/ping-to-warm-cloud-run`).
>
> The scheduled `min_instance_count = 1` window described below shipped 2026-05-07 and was
> retired at cutover on 2026-07-26. It cost 61,300 billable instance-seconds/day (10.6× the
> Cloud Run free CPU allowance) and 97% of that billed time was idle. It has been replaced by a
> single Cloud Scheduler job issuing `GET /health` every 5 minutes over 06:00–23:00
> `Pacific/Auckland`, with `min_instance_count` pinned to `0` permanently — 297 billable
> instance-seconds/day, 6.8% of the free allowance. The `cgrs-api-scale-up` /
> `cgrs-api-scale-down` jobs, the `cloud-run-scheduler` service account and its IAM bindings,
> and the `ignore_changes` on `min_instance_count` no longer exist. Nothing here is current.
>
> The 5 unchecked tasks below were deliberately left unchecked: they are work this change no
> longer needs done.

## Why

The `cgrs-api` Cloud Run service currently runs with `min_instances = 0`, which means every request after a period of inactivity pays a cold-start penalty. End users in NZ hit this whenever the service has been idle (most often the first request of the morning, or after a quiet stretch).

Keeping `min_instances = 1` 24/7 would eliminate cold starts but burn idle-CPU billing during overnight hours when traffic is effectively zero — and the cold start there isn't user-visible.

We want to keep one warm instance during NZ waking hours (06:00–22:59 Pacific/Auckland) and let the service scale to zero overnight (23:00–05:59 Pacific/Auckland), automatically and DST-aware.

Cloud Run has no native scheduled scaling. The standard pattern is Cloud Scheduler → Cloud Run Admin API on a cron. This proposal adds that pattern as a tofu-managed module.

## What Changes

- **New module** `modules/cloud-run-scheduler` — provisions a service account, IAM binding scoped to the target Cloud Run service, the Cloud Scheduler API enablement, and two `google_cloud_scheduler_job` resources that PATCH `template.scaling.minInstanceCount` on a NZ-local cron.
- **Update** `modules/cloud-run/main.tf` — add `template[0].scaling[0].min_instance_count` to `lifecycle.ignore_changes`. Tofu still defines the *initial* value via `var.cloud_run_min_instances`; the scheduler owns the *current* value.
- **Wire** the new module into `tofu/main.tf` and add corresponding variables to `tofu/variables.tf` and `environments/prod/prod.tfvars`.
- **Accept** that each scheduled PATCH creates a new Cloud Run revision (~2/day, ~730/year). Negligible cost; minor console clutter mitigated by Cloud Run's automatic revision GC.

## Capabilities

### New Capabilities

- `cloud-run-scheduled-scaling`: time-based scaling of Cloud Run min instances, expressed in NZ local time (Pacific/Auckland, DST-aware), driven by Cloud Scheduler PATCHing the Cloud Run Admin API.

### Modified Capabilities

_None — there are no existing specs in `openspec/specs/` to modify._

## Impact

- **Code**:
  - `modules/cloud-run-scheduler/{main.tf,variables.tf,outputs.tf}` (new)
  - `modules/cloud-run/main.tf` (one-line change to `ignore_changes`)
  - `tofu/main.tf`, `tofu/variables.tf`, `environments/prod/prod.tfvars`
- **GCP APIs newly required**: `cloudscheduler.googleapis.com`
- **GCP resources created**: 1 service account, 1 service-scoped IAM binding (`roles/run.developer`), 2 Cloud Scheduler jobs.
- **Cost**: Cloud Scheduler is free for the first 3 jobs/account. Keeping min=1 for ~17h/day is the dominant cost component, by design.
- **Operational**: noisier revision list (Cloud Run auto-prunes); failed scheduler runs result in *one* user-visible cold start at worst — accepted SLO.
- **Deploy flow**: `make plan` / `make apply` continues to work; min_instances is no longer asserted by tofu, so a drift in the live value will not cause plan churn.
