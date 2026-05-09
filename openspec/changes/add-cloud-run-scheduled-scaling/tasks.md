## 1. New `cloud-run-scheduler` module

- [x] 1.1 Create `modules/cloud-run-scheduler/variables.tf` with inputs: `project_id`, `location`, `service_name`, `service_account_id` (default `"cloud-run-scheduler"`), `warm_min_instances` (default `1`), `scale_up_cron` (default `"0 6 * * *"`), `scale_down_cron` (default `"0 23 * * *"`), `time_zone` (default `"Pacific/Auckland"`), `labels`.
- [x] 1.2 Create `modules/cloud-run-scheduler/main.tf` with: `google_project_service` enabling `cloudscheduler.googleapis.com`; `google_service_account` for the scheduler; `google_cloud_run_v2_service_iam_member` granting `roles/run.developer` *at the service resource* to the new SA; two `google_cloud_scheduler_job` resources (scale-up, scale-down) with `time_zone`, `http_target` PATCHing the Cloud Run Admin v2 endpoint with `updateMask=template.scaling.minInstanceCount`, OIDC auth via the new SA, and a body containing `{"template":{"scaling":{"minInstanceCount":N}}}`. _Notes: (a) implementation uses `oauth_token` (not `oidc_token`) since the target is a Google API endpoint; (b) Cloud Run v2 `services.patch` also requires the caller to have `roles/iam.serviceAccountUser` on the service's runtime SA — added as `google_service_account_iam_member.scheduler_act_as_runtime`. Discovered in production after the first PATCH attempt returned 403 PERMISSION_DENIED (audit log: "Permission 'iam.serviceaccounts.actAs' denied")._
- [x] 1.3 Create `modules/cloud-run-scheduler/outputs.tf` exposing the SA email and the two scheduler job names.

## 2. Update `cloud-run` module

- [x] 2.1 Add `template[0].scaling[0].min_instance_count` to `lifecycle.ignore_changes` on `google_cloud_run_v2_service.this` in `modules/cloud-run/main.tf`.
- [x] 2.2 Add a comment next to the `ignore_changes` block explaining that scheduled scaling owns the live value (mirrors the existing comment on `image`).

## 3. Wire the new module

- [x] 3.1 Add `module "cloud_run_scheduler"` block to `tofu/main.tf`, gated on `var.cloud_run_scheduler_enabled` and `var.cloud_run_enabled`. Pass the service name/location from the existing `module.cloud_run_api` outputs (or directly from variables).
- [x] 3.2 Add variables to `tofu/variables.tf`: `cloud_run_scheduler_enabled` (bool, default `true`), `cloud_run_warm_min_instances` (number, default `1`), `cloud_run_scale_up_cron` (string, default `"0 6 * * *"`), `cloud_run_scale_down_cron` (string, default `"0 23 * * *"`), `cloud_run_schedule_timezone` (string, default `"Pacific/Auckland"`).
- [x] 3.3 Set values explicitly in `environments/prod/prod.tfvars` (so prod choices are visible at the env level, not implied by module defaults).
- [x] 3.4 If `modules/cloud-run/outputs.tf` does not already export the service name/location, add the outputs needed for wiring. _Added `location` output; `service_name` already existed._

## 4. Apply and verify

- [x] 4.1 `make fmt && make validate`. _`tofu fmt` rewrote `prod.tfvars` alignment; `tofu validate` (after `tofu init -backend=false`) returned `Success! The configuration is valid.`_
- [x] 4.2 `make plan ENV=prod` and confirm: 1 SA created, 1 IAM member, 1 API enablement, 2 scheduler jobs; `min_instance_count` no longer in the diff for the cloud-run service. _Plan: 5 to add (matches expected), 2 to change (pre-existing cosmetic drift on cloud-run `client`/`client_version` and turnstile domains order — not from this change). `min_instance_count` confirmed absent from diff._
- [ ] 4.3 `make apply ENV=prod`.
- [ ] 4.4 Run `make scheduler-trigger-up ENV=prod` and verify with `make cloud-run-min-instances ENV=prod` that the live value is `1` and a new Cloud Run revision exists.
- [ ] 4.5 Run `make scheduler-trigger-down ENV=prod` and verify with `make cloud-run-min-instances ENV=prod` that the live value is `0`.
- [ ] 4.6 Run `make plan` again and confirm there is no drift on `cgrs-api`.
- [ ] 4.7 Observe the next *natural* scale-up at 06:00 NZ (one calendar day after deploy) — confirm via Cloud Scheduler job history that it ran successfully and via Cloud Run that a new revision exists.

## 5. Documentation

- [x] 5.1 Add a short note to the project README (or `environments/prod/README.md`) describing the warm-window schedule and how to disable it (`cloud_run_scheduler_enabled = false`) for incident response. _Added "Cloud Run scheduled scaling" section to `environments/prod/README.md`._
