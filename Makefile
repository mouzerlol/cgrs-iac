.PHONY: help init plan apply apply-saved destroy validate fmt check clean clean-plan \
        scheduler-trigger-up scheduler-trigger-down cloud-run-min-instances

# Default environment if not specified
ENV ?= prod

# Directories
ENV_DIR := environments/$(ENV)
TOFU_DIR := tofu

# Derived from the env's tfvars so this stays in sync with what tofu deploys.
GCP_PROJECT_ID := $(shell awk -F'"' '/^[[:space:]]*gcp_project_id[[:space:]]*=/ {print $$2}' $(ENV_DIR)/$(ENV).tfvars)
SERVICE_NAME := $(shell awk -F'"' '/^[[:space:]]*cloud_run_service_name[[:space:]]*=/ {print $$2}' $(ENV_DIR)/$(ENV).tfvars)
GCP_REGION ?= australia-southeast1

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf " %-20s %s\n", $$1, $$2}'

init: ## Initialize OpenTofu for environment (ENV=prod)
	@set -a && . environments/$(ENV)/.envrc && set +a && \
	cd $(TOFU_DIR) && tofu init -backend-config=../$(ENV_DIR)/$(ENV).tfbackend -reconfigure

plan: ## Run OpenTofu plan for environment (ENV=prod); saves plan to $(ENV).tfplan
	@set -a && . environments/$(ENV)/.envrc && set +a && \
	cd $(TOFU_DIR) && tofu plan \
		-var-file=../$(ENV_DIR)/$(ENV).tfvars \
		-out=../$(ENV_DIR)/$(ENV).tfplan

apply: ## Apply OpenTofu changes (interactive; uses current state, not a saved plan file)
	@set -a && . environments/$(ENV)/.envrc && set +a && \
	cd $(TOFU_DIR) && tofu apply \
		-var-file=../$(ENV_DIR)/$(ENV).tfvars

apply-saved: ## Apply the saved plan from make plan (if "Saved plan is stale", run make plan again)
	@set -a && . environments/$(ENV)/.envrc && set +a && \
	cd $(TOFU_DIR) && tofu apply \
		-var-file=../$(ENV_DIR)/$(ENV).tfvars \
		../$(ENV_DIR)/$(ENV).tfplan

destroy: ## Destroy resources for environment (ENV=prod)
	@set -a && . environments/$(ENV)/.envrc && set +a && \
	cd $(TOFU_DIR) && tofu destroy \
		-var-file=../$(ENV_DIR)/$(ENV).tfvars

validate: ## Validate OpenTofu configurations
	@set -a && . environments/$(ENV)/.envrc && set +a && \
	cd $(TOFU_DIR) && tofu validate

fmt: ## Format OpenTofu code
	cd $(TOFU_DIR) && tofu fmt -recursive
	@find . -name "*.tf" -o -name "*.tfvars" | xargs tofu fmt

check: fmt validate ## Run all quality checks (fmt + validate)

clean-plan: ## Remove saved plan file for ENV (optional; does not change remote state)
	rm -f $(ENV_DIR)/$(ENV).tfplan

clean: ## Clean up generated files
	rm -rf $(TOFU_DIR)/.tofu
	rm -rf environments/*/.tofu
	rm -f environments/*/*.tfplan
	rm -f environments/*/*.tfstate
	rm -f environments/*/*.tfstate.*

scheduler-trigger-up: ## Manually trigger the warm-window scale-up Cloud Scheduler job
	@set -a && . $(ENV_DIR)/.envrc && set +a && \
	gcloud scheduler jobs run $(SERVICE_NAME)-scale-up \
		--location=$(GCP_REGION) \
		--project=$(GCP_PROJECT_ID)

scheduler-trigger-down: ## Manually trigger the cold-window scale-down Cloud Scheduler job
	@set -a && . $(ENV_DIR)/.envrc && set +a && \
	gcloud scheduler jobs run $(SERVICE_NAME)-scale-down \
		--location=$(GCP_REGION) \
		--project=$(GCP_PROJECT_ID)

cloud-run-min-instances: ## Show the live min_instance_count on the Cloud Run service
	@set -a && . $(ENV_DIR)/.envrc && set +a && \
	gcloud run services describe $(SERVICE_NAME) \
		--region=$(GCP_REGION) \
		--project=$(GCP_PROJECT_ID) \
		--format='value(spec.template.metadata.annotations."autoscaling.knative.dev/minScale")'
