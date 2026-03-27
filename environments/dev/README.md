# Dev Environment

This directory contains the configuration for the development environment.

## Files

- `.envrc` - direnv configuration (loads `.env.dev`)
- `dev.tfvars` - OpenTofu variables
- `dev.tfbackend` - OpenTofu backend configuration

## Usage

```bash
# With direnv (auto-loads .envrc)
cd tofu
tofu init -backend-config=../dev/dev.tfbackend
tofu plan -var-file=../dev/dev.tfvars

# Or use Makefile
make init ENV=dev
make plan ENV=dev
make apply ENV=dev
```

## State

State is stored in R2 at `dev/cgrs.tfstate`.
