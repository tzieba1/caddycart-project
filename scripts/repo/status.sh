#!/bin/bash
# Show status of all repositories

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Show status header
show_header() {
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║                    CaddyCart Repository Status                       ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Mode: $(yq eval '.project.mode' config/orchestration.yaml)"
    echo ""
}

# Check repository status
check_repo_status() {
    local repo_name=$1
    local repo_info=$(yq eval ".repositories[] | select(.name == \"${repo_name}\")" registry/repositories.yaml)
    
    if [ -z "$repo_info" ]; then
        return
    fi
    
    local full_name=$(echo "$repo_info" | yq eval '.full_name' -)
    local repo_type=$(echo "$repo_info" | yq eval '.type' -)
    local version=$(echo "$repo_info" | yq eval '.version' -)
    local submodule_path=$(echo "$repo_info" | yq eval '.submodule_path' -)
    local dependencies=$(echo "$repo_info" | yq eval '.dependencies[]' - 2>/dev/null | tr '\n' ',' | sed 's/,$//')
    
    printf "%-20s " "${full_name}:"
    
    # Check if submodule exists
    if [ ! -d "${PROJECT_ROOT}/${submodule_path}" ]; then
        echo "❌ Not cloned"
        return
    fi
    
    cd "${PROJECT_ROOT}/${submodule_path}"
    
    # Get git status
    local branch=$(git branch --show-current 2>/dev/null || echo "detached")
    local changes=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    
    # Get latest tag
    local latest_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "no-tags")
    latest_tag=${latest_tag#v}
    
    # Check if behind/ahead
    git fetch origin &>/dev/null 2>&1 || true
    local ahead=$(git rev-list --count origin/main..HEAD 2>/dev/null || echo "0")
    local behind=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo "0")
    
    # Format output
    printf "v%-8s " "$version"
    printf "%-10s " "$branch"
    
    # Changes indicator
    if [ "$changes" -eq 0 ]; then
        printf "✓ "
    else
        printf "${YELLOW}●${NC} "
    fi
    
    # Sync status
    if [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
        printf "↕ "
    elif [ "$ahead" -gt 0 ]; then
        printf "↑ "
    elif [ "$behind" -gt 0 ]; then
        printf "↓ "
    else
        printf "✓ "
    fi
    
    # Type
    printf "%-6s " "$repo_type"
    
    # Dependencies
    if [ -n "$dependencies" ]; then
        echo "→ $dependencies"
    else
        echo ""
    fi
    
    cd - > /dev/null
}

# Show dependency tree
show_dependency_tree() {
    echo ""
    echo "Dependency Tree:"
    echo "────────────────"
    
    # Get repos with no dependencies (roots)
    local roots=$(yq eval '.repositories[] | select(.dependencies == [] or .dependencies == null) | .name' registry/repositories.yaml)
    
    for root in $roots; do
        print_tree_node "$root" 0
    done
}

# Print tree node recursively
print_tree_node() {
    local repo_name=$1
    local indent=$2
    
    # Print current node
    printf "%*s├─ %s (v%s)\n" $indent "" "$repo_name" "$(get_version "$repo_name")"
    
    # Find dependents
    local dependents=$(yq eval ".repositories[] | select(.dependencies[] == \"${repo_name}\") | .name" registry/repositories.yaml 2>/dev/null)
    
    for dependent in $dependents; do
        print_tree_node "$dependent" $((indent + 3))
    done
}

# Show statistics
show_statistics() {
    echo ""
    echo "Statistics:"
    echo "───────────"
    
    local total_repos=$(yq eval '.repositories | length' registry/repositories.yaml)
    local active_repos=$(yq eval '.repositories[] | select(.status == "active") | .name' registry/repositories.yaml | wc -l)
    
    # Count by type
    local core_count=$(yq eval '.repositories[] | select(.type == "core") | .name' registry/repositories.yaml | wc -l)
    local service_count=$(yq eval '.repositories[] | select(.type == "service") | .name' registry/repositories.yaml | wc -l)
    local app_count=$(yq eval '.repositories[] | select(.type == "application") | .name' registry/repositories.yaml | wc -l)
    
    echo "Total repositories: $total_repos"
    echo "Active repositories: $active_repos"
    echo ""
    echo "By type:"
    echo "  Core: $core_count"
    echo "  Service: $service_count"
    echo "  Application: $app_count"
}

# Main execution
main() {
    cd "${PROJECT_ROOT}"
    
    show_header
    
    echo "Repository Status:"
    echo "─────────────────────────────────────────────────────────────────────"
    printf "%-20s %-10s %-10s %-3s %-3s %-6s %s\n" "Repository" "Version" "Branch" "Ch" "Sy" "Type" "Dependencies"
    echo "─────────────────────────────────────────────────────────────────────"
    
    # Check each repository
    mapfile -t repos < <(yq eval '.repositories[].name' registry/repositories.yaml 2>/dev/null)
    
    for repo in "${repos[@]}"; do
        check_repo_status "$repo"
    done
    
    if [ ${#repos[@]} -eq 0 ]; then
        echo "No repositories registered yet."
        echo "Run 'make repo-create' to create your first repository."
    fi
    
    echo "─────────────────────────────────────────────────────────────────────"
    echo ""
    echo "Legend: Ch=Changes, Sy=Sync (✓=synced, ↑=ahead, ↓=behind, ↕=diverged)"
    
    # Show dependency tree if repos exist
    if [ ${#repos[@]} -gt 0 ]; then
        show_dependency_tree
        show_statistics
    fi
}

main "$@"