#!/bin/bash
# Migrate all repositories to organization account

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${PROJECT_ROOT}/scripts/lib/common.sh"

main() {
    local ORG_NAME=${1:-}
    local DRY_RUN=${2:-true}
    
    if [ -z "$ORG_NAME" ]; then
        echo "Usage: $0 <organization-name> [dry-run]"
        echo ""
        echo "Example:"
        echo "  $0 caddycart true     # Dry run"
        echo "  $0 caddycart false    # Execute migration"
        exit 1
    fi
    
    GITHUB_USER=$(yq eval '.project.owner' "${PROJECT_ROOT}/config/orchestration.yaml")
    
    log_header "Repository Migration to Organization"
    echo "From: @${GITHUB_USER}"
    echo "To: @${ORG_NAME}"
    echo "Mode: $([ "$DRY_RUN" = "true" ] && echo "DRY RUN" || echo "EXECUTE")"
    echo ""
    
    # Check organization exists
    if ! gh api "/orgs/${ORG_NAME}" &>/dev/null; then
        log_error "Organization ${ORG_NAME} does not exist"
        exit 1
    fi
    
    # Get all repositories
    mapfile -t repos < <(yq eval '.repositories[].name' "${PROJECT_ROOT}/registry/repositories.yaml")
    
    if [ "$DRY_RUN" = "false" ]; then
        read -p "Transfer ${#repos[@]} repositories to ${ORG_NAME}? (yes/no): " confirm
        if [[ ! $confirm =~ ^yes$ ]]; then
            log_warning "Migration cancelled"
            exit 0
        fi
    fi
    
    # Transfer each repository
    for repo in "${repos[@]}"; do
        local full_name="caddycart-${repo}"
        
        log_info "Transferring ${full_name}..."
        
        if [ "$DRY_RUN" = "true" ]; then
            echo "  [DRY RUN] Would transfer to ${ORG_NAME}"
        else
            gh api \
                --method POST \
                "/repos/${GITHUB_USER}/${full_name}/transfer" \
                --field new_owner="${ORG_NAME}" \
                --field new_name="${full_name}" \
                2>/dev/null && log_success "  Transferred" || log_warning "  Already transferred or error"
        fi
    done
    
    # Update configuration
    if [ "$DRY_RUN" = "false" ]; then
        log_info "Updating configuration..."
        
        # Update orchestration config
        yq eval -i ".project.owner = \"${ORG_NAME}\"" "${PROJECT_ROOT}/config/orchestration.yaml"
        yq eval -i ".project.mode = \"organization\"" "${PROJECT_ROOT}/config/orchestration.yaml"
        
        # Update registry URLs
        yq eval -i ".repositories[].github_url |= sub(\"${GITHUB_USER}\", \"${ORG_NAME}\")" \
            "${PROJECT_ROOT}/registry/repositories.yaml"
        
        # Update submodule URLs
        "${PROJECT_ROOT}/scripts/submodules/sync.sh"
        
        # Commit changes
        git add -A
        git commit -m "chore: migrate to organization ${ORG_NAME}

- Updated configuration
- Changed repository URLs
- Updated submodule references"
        
        log_success "Migration complete!"
    else
        log_info "Dry run complete. Run with 'false' to execute migration."
    fi
}

main "$@"