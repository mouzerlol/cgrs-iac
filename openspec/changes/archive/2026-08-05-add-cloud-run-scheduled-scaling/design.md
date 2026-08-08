## Context

`cgrs-api` runs on Cloud Run v2 in `australia-southeast1`, the closest GCP region to New Zealand. The service is fronted directly by user traffic (public, unauthenticated), so a cold start at the start of the day is a perceptible UX hit. Cloud Run's built-in min-instances field is a single static integer; varying it by time-of-day requires an external scheduler.

The repository is OpenTofu-managed with one prod environment. Modules are small and single-purpose (`cloud-run`, `artifact-registry`, `r2-bucket`, `turnstile`). The cloud-run module already uses `lifecycle.ignore_changes` to allow `gcloud run deploy`-style image updates without causing tofu drift, so there is precedent for letting an out-of-band system mutate a managed resource.

## Goals / Non-Goals

**Goals:**
- Keep one warm `cgrs-api` instance during 06:00–22:59 Pacific/Auckland.
- Scale to zero during 23:00–05:59 Pacific/Auckland.
- Automatic DST handling (no manual seasonal adjustment).
- All resources managed in this repo as IaC; reproducible via `make plan` / `make apply`.
- No tofu drift on subsequent applies, even though the live min-instance value will diverge from the variable.
- Failure mode is graceful: a missed scheduler run results in (at worst) one cold start, not an outage.

**Non-Goals:**
- Generalized autoscaling beyond min-instances. Max-instances and CPU/memory remain tofu-driven.
- Per-region or per-service scheduling beyond `cgrs-api`. The module is reusable, but only one wiring is in scope here.
- Eliminating new-revision-per-PATCH. Accepted as a tradeoff (see Decisions).
- Alerting on scheduler failures. Accepted SLO is "one cold start at worst".

## Decisions

### Pattern: Cloud Scheduler → Cloud Run Admin API (HTTP PATCH with OIDC)

Two `google_cloud_scheduler_job` resources, both with `time_zone = "Pacific/Auckland"`, target:

```
PATCH https://run.googleapis.com/v2/projects/{project}/locations/{location}/services/{service}
      ?updateMask=template.scaling.minInstanceCount

Body:  { "template": { "scaling": { "minInstanceCount": N } } }
Auth:  OIDC token from a dedicated service account
```

- **Scale-up job**: cron `0 6 * * *`, body `minInstanceCount = var.warm_min_instances` (default `1`).
- **Scale-down job**: cron `0 23 * * *`, body `minInstanceCount = 0`.

Rejected alternatives:
- *Cloud Scheduler → Pub/Sub → Cloud Function → Admin API* — extra moving parts; only worth it if we ever need conditional logic (e.g., "skip if a deploy is in progress"). Not needed today.
- *Cloud Scheduler → Cloud Workflows → Admin API* — declarative retries, but overkill for one API call.
- *External scheduler (GitHub Actions cron)* — depends on a non-GCP system for production behavior; harder to reason about; misses are silent.

### Tofu owns the *initial* min-instance value, scheduler owns the *current* value

`modules/cloud-run/main.tf` adds `template[0].scaling[0].min_instance_count` to `lifecycle.ignore_changes`. This mirrors how `image` is already handled. Consequence:

- First apply seeds `min_instance_count` from `var.cloud_run_min_instances` (default `0`).
- Scheduler subsequently mutates it on a daily rhythm.
- Subsequent `make plan` runs will not see this divergence as drift.

The alternative — removing the variable entirely and never letting tofu set it — was rejected because we still want a deterministic "what does a fresh deploy look like" answer.

### NZ time zone via Cloud Scheduler `time_zone`

Cloud Scheduler accepts an IANA zone string per job. `Pacific/Auckland` handles NZ DST automatically. No manual seasonal flips.

### Service account scope: per-service IAM, not project-wide

Create a dedicated SA `cloud-run-scheduler` and bind `roles/run.developer` *at the service resource level* (`google_cloud_run_v2_service_iam_member`), not at the project level. The scheduler can update only the one service it is meant to manage.

In addition to the service-scoped role, the scheduler SA must be granted `roles/iam.serviceAccountUser` *on the Cloud Run service's runtime SA* (the SA the container runs as — by default the Compute Engine default SA `<project_number>-compute@developer.gserviceaccount.com`). Cloud Run v2 `services.patch` enforces `iam.serviceAccounts.actAs` on the runtime SA even when the patch only touches scaling. Without this grant, every PATCH returns `403 PERMISSION_DENIED` with the message `Permission 'iam.serviceaccounts.actAs' denied on service account …`. The module accepts an optional `runtime_service_account_email` override; when empty it derives the default Compute Engine SA from a `google_project` data lookup. The grant is per-SA (not project-wide), preserving least-privilege.

### Accept new-revision-per-PATCH

Cloud Run v2 treats `template.scaling` as part of the revision template, so each PATCH creates a new revision (~730/year). Cost is effectively zero; revision list noise is mitigated by Cloud Run's automatic GC of untrafficked revisions. Workarounds (pre-baked dual revisions with traffic-split toggling) more than double the surface area to deploy and were rejected.

### Window edges

- Warm: 06:00–22:59 NZ (PATCH min=1 fires at 06:00).
- Cold: 23:00–05:59 NZ (PATCH min=0 fires at 23:00).

## Risks / Trade-offs

| Risk | Mitigation |
|---|---|
| Scheduler run fails (transient API error) | Cloud Scheduler retries by default (configurable). Worst case: one cold start. Accepted. |
| Tofu apply during the warm window resets min=0 via variable | `ignore_changes` on `min_instance_count` prevents this. Verified in tasks. |
| API enablement (`cloudscheduler.googleapis.com`) not present | Module enables it explicitly via `google_project_service`. |
| Service rename / region migration silently breaks the schedule | Scheduler module receives the cloud-run service name and region as inputs from `tofu/main.tf`; rename triggers an apply. |
| Revision list grows large | Cloud Run auto-GCs untrafficked revisions; functionally bounded. |
| Wrong PATCH body shape / `updateMask` rejected by API | Verified during apply: trigger the scale-up job manually post-apply, confirm 200 + revision created. Documented in tasks. |
| DST cutover | Handled by `time_zone = "Pacific/Auckland"`. No code change needed. |
