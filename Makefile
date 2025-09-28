# CaddyCart Meta-Orchestration Makefile

.PHONY: help
help: ## Show this help
	@echo "CaddyCart Meta-Orchestration System"
	@echo "===================================="
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

# Repository Management
.PHONY: repo-create
repo-create: ## Create a new repository (interactive)
	@./scripts/repo/create.sh

.PHONY: repo-list
repo-list: ## List all repositories
	@yq eval '.repositories[].name' registry/repositories.yaml

.PHONY: repo-status
repo-status: ## Show repository status
	@./scripts/repo/status.sh

# Submodule Management
.PHONY: submodules-init
submodules-init: ## Initialize all submodules
	@git submodule update --init --recursive

.PHONY: submodules-update
submodules-update: ## Update all submodules
	@git submodule update --remote --merge

.PHONY: submodules-sync
submodules-sync: ## Synchronize submodules with registry
	@./scripts/submodules/sync.sh

# Dependency Management
.PHONY: deps-check
deps-check: ## Check dependencies
	@./scripts/lib/dependencies.sh check

.PHONY: deps-tree
deps-tree: ## Show dependency tree
	@./scripts/lib/dependencies.sh tree

.PHONY: deps-update
deps-update: ## Update dependency versions
	@./scripts/lib/dependencies.sh update

# Release Management
.PHONY: release
release: ## Orchestrate a release (VERSION=x.y.z)
	@./scripts/release/orchestrate.sh $(VERSION)

.PHONY: release-dry
release-dry: ## Dry run release (VERSION=x.y.z)
	@./scripts/release/orchestrate.sh $(VERSION) dependency-order true

.PHONY: version-bump
version-bump: ## Bump version (REPO=name TYPE=major|minor|patch)
	@./scripts/release/bump-version.sh $(REPO) $(TYPE)

# Issue Management
.PHONY: milestone-create
milestone-create: ## Create global milestone
	@./scripts/issues/sync.sh milestone

.PHONY: issue-create
issue-create: ## Create cross-repo issue
	@./scripts/issues/sync.sh issue

.PHONY: labels-sync
labels-sync: ## Synchronize labels across repos
	@./scripts/issues/sync.sh labels

# Development
.PHONY: setup
setup: ## Initial setup
	@echo "Setting up CaddyCart Meta-Orchestration..."
	@git submodule update --init --recursive
	@mkdir -p modules
	@echo "✓ Setup complete"

.PHONY: validate
validate: ## Validate all configurations
	@echo "Validating configurations..."
	@yq eval '.' config/orchestration.yaml > /dev/null
	@yq eval '.' registry/repositories.yaml > /dev/null
	@yq eval '.' registry/dependencies.yaml > /dev/null
	@echo "✓ All configurations valid"

.PHONY: clean
clean: ## Clean temporary files
	@find . -name "*.bak" -delete
	@find . -name "*.tmp" -delete
	@echo "✓ Cleaned"