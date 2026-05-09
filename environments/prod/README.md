# Prod Environment

This directory contains the configuration for the production environment.

## Files

- `.envrc` - direnv configuration (loads `.env.prod`)
- `prod.tfvars` - OpenTofu variables
- `prod.tfbackend` - OpenTofu backend configuration

## Usage

```bash
# With direnv (auto-loads .envrc)
cd tofu
tofu init -backend-config=../prod/prod.tfbackend
tofu plan -var-file=../prod/prod.tfvars

# Or use Makefile
make init ENV=prod
make plan ENV=prod
make apply ENV=prod
```

## State

State is stored in R2 at `prod/cgrs.tfstate`.

## Cloud Run scheduled scaling

`cgrs-api` is kept warm (`min_instance_count = 1`) during NZ waking hours and scaled to zero overnight, via two `google_cloud_scheduler_job` resources in the `cloud-run-scheduler` module:

- **Warm window:** 06:00–22:59 `Pacific/Auckland` (DST-aware)
- **Cold window:** 23:00–05:59 `Pacific/Auckland` (cold starts accepted)

The live `min_instance_count` is owned by Cloud Scheduler at runtime. Tofu does not reconcile drift on this field (`ignore_changes` in `modules/cloud-run/main.tf`).

### Operating

```bash
make scheduler-trigger-up ENV=prod      # force warm now (min=1)
make scheduler-trigger-down ENV=prod    # force cold now (min=0)
make cloud-run-min-instances ENV=prod   # show live min_instance_count
```

### Disabling during an incident

```bash
# In environments/prod/prod.tfvars
cloud_run_scheduler_enabled = false
make apply ENV=prod
```

This destroys the scheduler jobs, IAM binding, and service account. The live `min_instance_count` retains its last value until an operator updates it.

## Warning

Production changes should be reviewed carefully. CI/CD workflow requires approval before applying.
