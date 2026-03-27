.PHONY: help init plan apply validate fmt check clean

# Default environment if not specified
ENV ?= prod

# Directories
ENV_DIR := environments/$(ENV)
TOFU_DIR := tofu

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf " %-20s %s\n", $$1, $$2}'

init: ## Initialize OpenTofu for environment (ENV=prod)
	@if [ ! -d "$(ENV_DIR)" ]; then \
		echo "Error: Environment '$(ENV)' not found at $(ENV_DIR)"; \
		exit 1; \
	fi
	cd $(TOFU_DIR) && tofu init \
		-backend-config=../$(ENV_DIR)/$(ENV).tfbackend \
		-backend-config=path=$(ENV)/cgrs.tfstate

plan: ## Run OpenTofu plan for environment (ENV=prod)
	cd $(TOFU_DIR) && tofu plan \
		-backend-config=../$(ENV_DIR)/$(ENV).tfbackend \
		-var-file=../$(ENV_DIR)/$(ENV).tfvars \
		-out=../$(ENV_DIR)/$(ENV).tfplan

apply: ## Apply OpenTofu changes for environment (ENV=prod)
	cd $(TOFU_DIR) && tofu apply \
		-backend-config=../$(ENV_DIR)/$(ENV).tfbackend \
		-var-file=../$(ENV_DIR)/$(ENV).tfvars \
		../$(ENV_DIR)/$(ENV).tfplan

destroy: ## Destroy resources for environment (ENV=prod)
	cd $(TOFU_DIR) && tofu destroy \
		-backend-config=../$(ENV_DIR)/$(ENV).tfbackend \
		-var-file=../$(ENV_DIR)/$(ENV).tfvars

validate: ## Validate OpenTofu configurations
	cd $(TOFU_DIR) && tofu validate

fmt: ## Format OpenTofu code
	cd $(TOFU_DIR) && tofu fmt -recursive
	@find . -name "*.tf" -o -name "*.tfvars" | xargs tofu fmt

check: fmt validate ## Run all quality checks (fmt + validate)

clean: ## Clean up generated files
	rm -rf $(TOFU_DIR)/.tofu
	rm -rf environments/*/.tofu
	rm -f environments/*/*.tfplan
	rm -f environments/*/*.tfstate
	rm -f environments/*/*.tfstate.*
