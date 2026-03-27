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

## Warning

Production changes should be reviewed carefully. CI/CD workflow requires approval before applying.
