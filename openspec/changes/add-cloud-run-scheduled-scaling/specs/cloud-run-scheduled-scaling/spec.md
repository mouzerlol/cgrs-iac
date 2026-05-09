## ADDED Requirements

### Requirement: Warm window scaling

The `cgrs-api` Cloud Run service SHALL run with a minimum of `var.cloud_run_warm_min_instances` (default `1`) instances during the configured warm window in NZ local time.

#### Scenario: Inside warm window
- **WHEN** the current time in `Pacific/Auckland` is between 06:00 and 22:59 inclusive
- **THEN** the Cloud Run service `template.scaling.minInstanceCount` is `var.cloud_run_warm_min_instances`

### Requirement: Off-hours scale-to-zero

The `cgrs-api` Cloud Run service SHALL allow scale-to-zero outside the warm window.

#### Scenario: Outside warm window
- **WHEN** the current time in `Pacific/Auckland` is between 23:00 and 05:59 inclusive
- **THEN** the Cloud Run service `template.scaling.minInstanceCount` is `0`

### Requirement: Schedule expressed in NZ local time, DST-aware

The schedule SHALL be expressed in `Pacific/Auckland` time and SHALL automatically follow NZ daylight-saving transitions without manual adjustment.

#### Scenario: NZDT in effect
- **WHEN** New Zealand is in daylight time (e.g. January)
- **THEN** the scale-up and scale-down jobs fire at 06:00 NZDT and 23:00 NZDT respectively

#### Scenario: NZST in effect
- **WHEN** New Zealand is in standard time (e.g. July)
- **THEN** the scale-up and scale-down jobs fire at 06:00 NZST and 23:00 NZST respectively

### Requirement: No tofu drift from scheduled changes

A subsequent `tofu plan` SHALL NOT report drift on `min_instance_count` after a scheduled job has mutated the live value.

#### Scenario: Plan after scheduler runs
- **WHEN** the scale-up or scale-down job has executed and changed the live `minInstanceCount`
- **AND** an operator runs `make plan ENV=prod`
- **THEN** the plan reports no changes attributable to `min_instance_count` on the `cgrs-api` service

### Requirement: Graceful failure mode

A failed scheduled job execution SHALL NOT take the service down. The service SHALL continue to serve traffic at whatever `minInstanceCount` was last set.

#### Scenario: Scale-up job fails
- **WHEN** the 06:00 scale-up job fails to PATCH the Admin API
- **THEN** the service continues to operate with the previous `minInstanceCount` (likely `0`)
- **AND** the next user request triggers a single cold start, which is the accepted SLO

### Requirement: Least-privilege scheduler identity

The scheduler SHALL authenticate using a dedicated service account whose IAM grant is scoped to the target Cloud Run service, not the project.

#### Scenario: SA cannot affect other services
- **WHEN** the scheduler service account attempts to PATCH a Cloud Run service other than `cgrs-api`
- **THEN** the request is denied by IAM

### Requirement: Optional disablement for incident response

The scheduled-scaling behavior SHALL be toggleable via a single tofu variable so operators can disable it during incidents (e.g., to pin min=1 manually) without removing module code.

#### Scenario: Disable via variable
- **WHEN** `var.cloud_run_scheduler_enabled` is `false`
- **AND** `make apply ENV=prod` runs
- **THEN** the scheduler jobs, IAM binding, and service account are not provisioned (or are destroyed if previously present)
- **AND** the live `minInstanceCount` retains whatever value was last set (operator-managed from that point)
