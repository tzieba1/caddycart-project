#!/bin/bash
# Update all submodules to their latest commits

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${PROJECT_ROOT}/scripts/lib/common.sh"

main() {
    log_header "Updating All Submodules"
    
    cd "${PROJECT_ROOT}"
    
    # Initialize submodules if needed
    log_info "Initializing submodules..."
    git submodule init
    
    # Update each submodule
    log_info "Updating submodules to latest commits..."
    git submodule foreach 'git fetch origin && git checkout main && git pull origin main'
    
    # Update registry with new versions
    log_info "Updating version registry..."
    
    for module in modules/*; do
        if [ -d "$module" ]; then
            repo_name=$(basename "$module")
            
            cd "$module"
            
            # Get current version from git
            current_version=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
            current_version=${current_version#v}
            
            cd "${PROJECT_ROOT}"
            
            # Update registry
            update_version "$repo_name" "$current_version"
            
            log_success "Updated ${repo_name} to v${current_version}"
        fi
    done
    
    # Commit updates
    if ! git diff --quiet; then
        git add -A
        git commit -m "chore: update submodules to latest versions

- Pulled latest changes from all submodules
- Updated version registry"
        
        log_success "Committed submodule updates"
    else
        log_info "No updates needed"
    fi
}

main "$@"