#!/bin/bash
# Complete dependency management library

# Source common functions if not already sourced
if [ -z "$PROJECT_ROOT" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
    source "${PROJECT_ROOT}/scripts/lib/common.sh"
fi

# Check all dependencies
check() {
    log_header "Dependency Check"
    
    local has_errors=false
    
    # Check for circular dependencies
    log_info "Checking for circular dependencies..."
    if check_all_circular_dependencies; then
        log_success "No circular dependencies found"
    else
        log_error "Circular dependencies detected"
        has_errors=true
    fi
    
    # Check version compatibility
    log_info "Checking version compatibility..."
    if check_version_compatibility; then
        log_success "All versions compatible"
    else
        log_error "Version incompatibilities found"
        has_errors=true
    fi
    
    # Check dependency depth
    log_info "Checking dependency depth..."
    if check_dependency_depth; then
        log_success "Dependency depth within limits"
    else
        log_warning "Some repositories exceed recommended dependency depth"
    fi
    
    if [ "$has_errors" = true ]; then
        return 1
    fi
    
    return 0
}

# Show dependency tree for all repositories
tree() {
    log_header "Dependency Tree"
    
    # Get all repositories
    mapfile -t repos < <(yq eval '.repositories[].name' "${PROJECT_ROOT}/registry/repositories.yaml")
    
    if [ ${#repos[@]} -eq 0 ]; then
        log_info "No repositories registered"
        return
    fi
    
    # Find root repositories (no dependencies)
    local roots=()
    for repo in "${repos[@]}"; do
        local deps=$(get_repo_info "$repo" "dependencies")
        if [ -z "$deps" ] || [ "$deps" = "[]" ] || [ "$deps" = "null" ]; then
            roots+=("$repo")
        fi
    done
    
    # Print tree from each root
    for root in "${roots[@]}"; do
        print_dependency_tree "$root" 0 ""
    done
}

# Print dependency tree for a repository
print_dependency_tree() {
    local repo=$1
    local level=$2
    local prefix=$3
    
    # Get repo info
    local version=$(get_repo_info "$repo" "version")
    local type=$(get_repo_info "$repo" "type")
    
    # Print current node
    if [ $level -eq 0 ]; then
        echo "📦 ${repo} (v${version}) [${type}]"
    else
        echo "${prefix}├─ ${repo} (v${version}) [${type}]"
    fi
    
    # Get dependents
    local dependents=$(yq eval ".repositories[] | select(.dependencies[] == \"${repo}\") | .name" \
        "${PROJECT_ROOT}/registry/repositories.yaml" 2>/dev/null)
    
    if [ -n "$dependents" ]; then
        local dependent_array=($dependents)
        local count=${#dependent_array[@]}
        local i=0
        
        for dependent in "${dependent_array[@]}"; do
            i=$((i + 1))
            local new_prefix="${prefix}│  "
            
            if [ $i -eq $count ]; then
                new_prefix="${prefix}   "
            fi
            
            print_dependency_tree "$dependent" $((level + 1)) "$new_prefix"
        done
    fi
}

# Update dependency versions
update() {
    log_header "Update Dependencies"
    
    # Get all repositories
    mapfile -t repos < <(yq eval '.repositories[].name' "${PROJECT_ROOT}/registry/repositories.yaml")
    
    for repo in "${repos[@]}"; do
        update_repository_dependencies "$repo"
    done
    
    log_success "Dependencies updated"
}

# Update dependencies for a single repository
update_repository_dependencies() {
    local repo=$1
    local submodule_path="modules/${repo}"
    
    if [ ! -d "${PROJECT_ROOT}/${submodule_path}" ]; then
        return
    fi
    
    local deps=$(get_repo_info "$repo" "dependencies")
    
    if [ -z "$deps" ] || [ "$deps" = "[]" ] || [ "$deps" = "null" ]; then
        return
    fi
    
    log_info "Updating dependencies for ${repo}..."
    
    cd "${PROJECT_ROOT}/${submodule_path}"
    
    # Update dependencies.yaml if it exists
    if [ -f "dependencies.yaml" ]; then
        echo "$deps" | yq eval '.[]' - | while read -r dep; do
            local dep_version=$(get_repo_info "$dep" "version")
            
            yq eval -i "(.dependencies[] | select(.name == \"${dep}\") | .version) = \"^${dep_version}\"" \
                dependencies.yaml
        done
        
        git add dependencies.yaml
        git commit -m "chore: update dependency versions" || true
    fi
    
    cd "${PROJECT_ROOT}"
}

# Check all repositories for circular dependencies
check_all_circular_dependencies() {
    mapfile -t repos < <(yq eval '.repositories[].name' "${PROJECT_ROOT}/registry/repositories.yaml")
    
    for repo in "${repos[@]}"; do
        if ! check_circular_dependencies "$repo"; then
            return 1
        fi
    done
    
    return 0
}

# Check version compatibility
check_version_compatibility() {
    local has_errors=false
    
    # Check each edge in dependency graph
    local edges=$(yq eval '.graph.edges[]' "${PROJECT_ROOT}/registry/dependencies.yaml" 2>/dev/null)
    
    if [ -z "$edges" ]; then
        return 0
    fi
    
    echo "$edges" | yq eval -o=json | jq -r '"\(.from)|\(.to)|\(.version_constraint)"' | \
    while IFS='|' read -r from to constraint; do
        local to_version=$(get_repo_info "$to" "version")
        
        if ! version_satisfies "$to_version" "$constraint"; then
            log_error "${from} requires ${to} ${constraint}, but ${to} is v${to_version}"
            has_errors=true
        fi
    done
    
    [ "$has_errors" = false ]
}

# Check if version satisfies constraint
version_satisfies() {
    local version=$1
    local constraint=$2
    
    # Simple implementation - just check major version for ^ constraints
    if [[ $constraint == ^* ]]; then
        local required_major=${constraint#^}
        required_major=${required_major%%.*}
        local actual_major=${version%%.*}
        
        [ "$actual_major" = "$required_major" ]
    else
        # For exact versions
        [ "$version" = "$constraint" ]
    fi
}

# Check dependency depth
check_dependency_depth() {
    local max_depth=$(yq eval '.dependency_rules[] | select(.name == "dependency_depth_limit") | .max_depth' \
        "${PROJECT_ROOT}/config/orchestration.yaml")
    
    if [ -z "$max_depth" ]; then
        max_depth=3
    fi
    
    local has_warnings=false
    
    mapfile -t repos < <(yq eval '.repositories[].name' "${PROJECT_ROOT}/registry/repositories.yaml")
    
    for repo in "${repos[@]}"; do
        local depth=$(calculate_dependency_depth "$repo" 0)
        
        if [ $depth -gt $max_depth ]; then
            log_warning "${repo} has dependency depth of ${depth} (max: ${max_depth})"
            has_warnings=true
        fi
    done
    
    [ "$has_warnings" = false ]
}

# Calculate dependency depth for a repository
calculate_dependency_depth() {
    local repo=$1
    local current_depth=$2
    
    local deps=$(get_repo_info "$repo" "dependencies")
    
    if [ -z "$deps" ] || [ "$deps" = "[]" ] || [ "$deps" = "null" ]; then
        echo $current_depth
        return
    fi
    
    local max_depth=$current_depth
    
    echo "$deps" | yq eval '.[]' - | while read -r dep; do
        local dep_depth=$(calculate_dependency_depth "$dep" $((current_depth + 1)))
        
        if [ $dep_depth -gt $max_depth ]; then
            max_depth=$dep_depth
        fi
    done
    
    echo $max_depth
}

# Analyze dependencies and generate report
analyze() {
    log_header "Dependency Analysis"
    
    echo "## Dependency Analysis Report"
    echo ""
    echo "Generated: $(date -I)"
    echo ""
    
    # Statistics
    echo "### Statistics"
    echo ""
    
    local total_repos=$(yq eval '.repositories | length' "${PROJECT_ROOT}/registry/repositories.yaml")
    local total_deps=$(yq eval '.graph.edges | length' "${PROJECT_ROOT}/registry/dependencies.yaml")
    
    echo "- Total repositories: ${total_repos}"
    echo "- Total dependencies: ${total_deps}"
    echo ""
    
    # Repository types
    echo "### Repository Types"
    echo ""
    
    yq eval '.repository_types | keys | .[]' "${PROJECT_ROOT}/config/orchestration.yaml" | while read -r type; do
        local count=$(yq eval ".repositories[] | select(.type == \"${type}\") | .name" \
            "${PROJECT_ROOT}/registry/repositories.yaml" | wc -l)
        echo "- ${type}: ${count}"
    done
    echo ""
    
    # Dependency graph
    echo "### Dependency Graph"
    echo ""
    echo '```mermaid'
    echo 'graph TD'
    
    yq eval '.graph.edges[]' "${PROJECT_ROOT}/registry/dependencies.yaml" 2>/dev/null | \
        yq eval -o=json | jq -r '"    \(.from) --> \(.to)"'
    
    echo '```'
    echo ""
    
    # Most depended upon
    echo "### Most Depended Upon"
    echo ""
    
    declare -A dep_count
    
    yq eval '.graph.edges[].to' "${PROJECT_ROOT}/registry/dependencies.yaml" 2>/dev/null | while read -r dep; do
        ((dep_count[$dep]++))
    done
    
    for dep in "${!dep_count[@]}"; do
        echo "- ${dep}: ${dep_count[$dep]} dependents"
    done | sort -t: -k2 -rn
}

# Main function for CLI usage
main() {
    local action=${1:-help}
    
    case $action in
        check)
            check
            ;;
        tree)
            tree
            ;;
        update)
            update
            ;;
        analyze)
            analyze
            ;;
        *)
            echo "Usage: $0 {check|tree|update|analyze}"
            exit 1
            ;;
    esac
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi