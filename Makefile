.PHONY: help init plan apply apply-saved destroy validate fmt check clean clean-plan

# Default environment if not specified
ENV ?= prod

# Directories
ENV_DIR := environments/$(ENV)
TOFU_DIR := tofu

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
