#!/bin/bash
# Orchestrate releases across all repositories

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${PROJECT_ROOT}/scripts/lib/common.sh"
source "${PROJECT_ROOT}/scripts/lib/dependencies.sh"

# Determine release order based on dependencies
determine_release_order() {
    local repos=()
    local ordered=()
    local visited=()
    
    # Get all active repositories
    mapfile -t repos < <(yq eval '.repositories[] | select(.status == "active") | .name' \
        "${PROJECT_ROOT}/registry/repositories.yaml")
    
    # Topological sort
    visit_node() {
        local node=$1
        
        # Check if already visited
        for v in "${visited[@]}"; do
            [[ "$v" == "$node" ]] && return
        done
        
        visited+=("$node")
        
        # Visit dependencies first
        local deps=$(get_repo_info "$node" "dependencies")
        if [ -n "$deps" ] && [ "$deps" != "[]" ]; then
            echo "$deps" | yq eval '.[]' - | while read -r dep; do
                visit_node "$dep"
            done
        fi
        
        ordered+=("$node")
    }
    
    # Visit all nodes
    for repo in "${repos[@]}"; do
        visit_node "$repo"
    done
    
    # Return ordered list
    printf '%s\n' "${ordered[@]}"
}

# Release a single repository
release_repository() {
    local repo_name=$1
    local version=$2
    local dry_run=$3
    
    local submodule_path="modules/${repo_name}"
    
    if [ ! -d "$submodule_path" ]; then
        log_warning "Repository ${repo_name} not found, skipping"
        return
    fi
    
    log_info "Releasing ${repo_name} v${version}"
    
    cd "${PROJECT_ROOT}/${submodule_path}"
    
    if [ "$dry_run" == "true" ]; then
        log_info "[DRY RUN] Would release ${repo_name} v${version}"
        cd "${PROJECT_ROOT}"
        return
    fi
    
    # Check for uncommitted changes
    if ! git diff --quiet || ! git diff --staged --quiet; then
        log_error "Uncommitted changes in ${repo_name}"
        cd "${PROJECT_ROOT}"
        return 1
    fi
    
    # Update version in package.json or VERSION file
    if [ -f "package.json" ]; then
        npm version "${version}" --no-git-tag-version
        git add package.json
    elif [ -f "VERSION" ]; then
        echo "${version}" > VERSION
        git add VERSION
    fi
    
    # Update dependencies.yaml if exists
    if [ -f "dependencies.yaml" ]; then
        # Update dependency versions to latest
        local deps=$(yq eval '.dependencies[].name' dependencies.yaml)
        for dep in $deps; do
            local dep_version=$(get_version "$dep")
            yq eval -i "(.dependencies[] | select(.name == \"$dep\") | .version) = \"^${dep_version}\"" \
                dependencies.yaml
        done
        git add dependencies.yaml
    fi
    
    # Commit version changes
    git commit -m "chore: release v${version}" || true
    
    # Create tag
    git tag -a "v${version}" -m "Release v${version}

Part of CaddyCart coordinated release
Dependencies updated to latest versions"
    
    # Push changes
    git push origin main
    git push origin "v${version}"
    
    # Create GitHub release
    gh release create "v${version}" \
        --title "v${version}" \
        --generate-notes \
        --target main
    
    # Update registry
    update_version "$repo_name" "$version"
    
    cd "${PROJECT_ROOT}"
    
    log_success "Released ${repo_name} v${version}"
}

# Main orchestration
orchestrate_release() {
    local version=$1
    local strategy=${2:-sequential}  # sequential | parallel | dependency-order
    local dry_run=${3:-true}
    
    log_header "Release Orchestration v${version}"
    
    # Determine release order
    log_info "Determining release order..."
    mapfile -t release_order < <(determine_release_order)
    
    echo "Release order:"
    for repo in "${release_order[@]}"; do
        echo "  - ${repo}"
    done
    echo ""
    
    # Confirm release
    if [ "$dry_run" != "true" ]; then
        read -p "Proceed with release? (y/n): " confirm
        [[ ! $confirm =~ ^[Yy]$ ]] && exit 0
    fi
    
    # Release each repository
    local failed=()
    
    for repo in "${release_order[@]}"; do
        if ! release_repository "$repo" "$version" "$dry_run"; then
            failed+=("$repo")
            
            if [ "$strategy" == "dependency-order" ]; then
                log_error "Failed to release ${repo}, stopping due to dependency order"
                break
            fi
        fi
    done
    
    # Update submodules
    log_info "Updating submodule references..."
    "${PROJECT_ROOT}/scripts/submodules/sync.sh"
    
    # Summary
    echo ""
    if [ ${#failed[@]} -eq 0 ]; then
        log_success "Release orchestration completed successfully!"
        
        # Commit meta-repository changes
        git add -A
        git commit -m "chore: orchestrated release v${version}

- Released all repositories
- Updated submodule references
- Synchronized registry"
        
        git tag -a "release-v${version}" -m "Orchestrated release v${version}"
        
    else
        log_error "Release failed for: ${failed[*]}"
        exit 1
    fi
}

# Main execution
main() {
    cd "${PROJECT_ROOT}"
    
    VERSION=${1:-}
    STRATEGY=${2:-dependency-order}
    DRY_RUN=${3:-true}
    
    if [ -z "$VERSION" ]; then
        echo "Usage: $0 <version> [strategy] [dry-run]"
        echo ""
        echo "Strategies:"
        echo "  - dependency-order: Release in dependency order (default)"
        echo "  - sequential: Release one by one"
        echo "  - parallel: Release all at once"
        echo ""
        echo "Examples:"
        echo "  $0 1.0.0                    # Dry run"
        echo "  $0 1.0.0 dependency-order false  # Real release"
        exit 1
    fi
    
    orchestrate_release "$VERSION" "$STRATEGY" "$DRY_RUN"
}

main "$@"