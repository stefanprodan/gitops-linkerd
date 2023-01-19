# Flux local dev environment with Docker and Kubernetes KIND
# Requirements:
# - Docker
# - Homebrew

.PHONY: tools
tools: ## Install Kubernetes kind, kubectl, FLux CLI and other tools with Homebrew
	brew bundle

.PHONY: validate
validate: ## Validate the Kubernetes manifests (including Flux custom resources)
	scripts/test/validate.sh

.PHONY: help
help:  ## Display this help menu
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
