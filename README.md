# CGRS Infrastructure as Code

OpenTofu infrastructure for the CGRS project, managing Cloudflare R2 storage.

## Prerequisites

- [OpenTofu](https://opentofu.org/) >= 1.10
- [direnv](https://direnv.net/) (optional, for auto-loading environment variables)
- AWS CLI v2 (for R2 S3-compatible API)
- GitHub CLI (optional, for secrets management)

## Project Structure

```
cgrs-iac/
├── environments/           # Environment-specific configurations
│   ├── dev/              # Development environment
│   └── prod/             # Production environment
├── modules/              # Reusable modules
│   └── r2-bucket/        # R2 bucket module
├── tofu/                 # Root configuration
├── .github/workflows/    # CI/CD pipelines
└── Makefile             # Development tasks
```

## Quick Start

### 1. Clone and Setup

```bash
cd cgrs-iac

# Copy environment files
cp .env.example environments/dev/.env.dev
cp .env.example environments/prod/.env.prod

# Edit the .env files with your credentials
```

### 2. Initialize

```bash
# Using Makefile
make init ENV=dev

# Or manually
cd tofu
tofu init -backend-config=../environments/dev/dev.tfbackend
```

### 3. Plan and Apply

```bash
# Plan changes
make plan ENV=dev

# Apply changes (be careful in prod!)
make apply ENV=dev
```

## Environment Configuration

Each environment has three configuration files:

| File | Purpose |
|------|---------|
| `.envrc` | direnv configuration (loads secrets) |
| `.tfvars` | Environment variables for OpenTofu |
| `.tfbackend` | Backend configuration for state storage |

### Available Environments

- **dev** - Development environment
- **prod** - Production environment

## Makefile Commands

```bash
make help              # Show all available commands
make init ENV=dev      # Initialize OpenTofu for environment
make plan ENV=dev      # Create execution plan
make apply ENV=dev     # Apply changes
make validate          # Validate configurations
make fmt               # Format code
make check             # Run fmt + validate
make clean             # Clean up generated files
```

## State Management

State is stored in Cloudflare R2 using the S3-compatible API:

```
cgrs-state-storage/
├── dev/cgrs.tfstate
└── prod/cgrs.tfstate
```

### State Locking Limitation

The R2 backend does not currently support state locking. OpenTofu's S3 backend can use `use_lockfile = true` for S3-compatible services that support conditional writes, but R2's ETag behavior means locking is not reliable.

**Mitigation:** Ensure only one operator applies changes at a time. The GitHub Actions workflow applies production changes sequentially.

For a native R2 backend with locking, watch [OpenTofu PR #3076](https://github.com/opentofu/opentofu/issues/3076).

## Modules

### R2 Bucket (`modules/r2-bucket/`)

Creates R2 buckets with:
- Server-side encryption (AES256)
- Versioning (optional)
- Public access blocking
- Static website hosting (optional)

## CI/CD

### Pull Request Workflow

On pull requests to `main`:
1. Format check
2. Validate configurations
3. Plan for both dev and prod environments
4. Comment plan output on PR

### Apply Workflow

On push to `main`:
1. Validate
2. Plan production
3. Require production approval
4. Apply production changes

### Required Secrets

Configure these in GitHub repository settings:

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | R2 access key ID |
| `AWS_SECRET_ACCESS_KEY` | R2 secret access key |
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token |

Configure these as repository variables:

| Variable | Description |
|----------|-------------|
| `AWS_ENDPOINT` | R2 endpoint URL |
| `AWS_REGION` | Region (auto for R2) |
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare account ID |

## Couplings to other repos

### Cloud Run sleep window ↔ frontend cold-start banner

The `cloud-run-keep-warm` module **no longer sets `min_instance_count`**. It runs
a single Cloud Scheduler job that issues `GET /health` against the Cloud Run API
service every 5 minutes during the warm window, keeping an instance resident
without paying for idle time. `min_instance_count` is pinned to `0` permanently
and is owned by Tofu. The window is configured via `cloud_run_ping_cron`,
`cloud_run_warm_window_start_hour` and `cloud_run_warm_window_end_hour` in the
env tfvars (see `environments/prod/prod.tfvars` and
`environments/prod/README.md` for the full mechanism and cost basis).

Note the directory is `modules/cloud-run-keep-warm` (renamed from
`cloud-run-scheduler`), but the Tofu module **block** in `tofu/main.tf` is still
called `cloud_run_scheduler` on purpose. Module `source` paths are not recorded
in state, so renaming the directory is free; renaming the block would re-address
every resource inside it and force a destroy/create of the service account,
whose ID GCP then tombstones for 30 days.

The cgrs-frontend's cold-start banner needs to know the same window so it can
predict when the API will be cold and render a wake-up indicator. It reads the
hours from `NEXT_PUBLIC_SLEEP_WINDOW_START_HOUR` and
`NEXT_PUBLIC_SLEEP_WINDOW_END_HOUR` at build time.

**To keep them in sync**: the root tofu stack exposes a `cloud_run_sleep_window`
output (`scale_up_hour`, `scale_down_hour`, `time_zone`) — names kept verbatim
as the frontend contract, now sourced from the warm-window hour variables rather
than parsed out of the retired scaling crons. A deploy pipeline should read those
outputs and inject them as `NEXT_PUBLIC_*` vars when building the frontend.
Changing the window without the matching frontend rebuild causes the banner to
mis-fire or under-fire.

If you change the window hours in tfvars, either:
- Run the frontend deploy pipeline so it picks up the new outputs, or
- Manually update `NEXT_PUBLIC_SLEEP_WINDOW_*_HOUR` in the Vercel project env.

## Extensibility

The project structure supports adding:

- `modules/gcp-project/` - GCP resources
- `modules/postgres/` - Neon Postgres or Cloudflare D1
- `environments/staging/` - Staging environment

## License

Internal use only.
