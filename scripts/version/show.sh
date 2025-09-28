#!/bin/bash
# Show versions of all repositories

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${PROJECT_ROOT}/scripts/lib/common.sh"

main() {
    log_header "Repository Versions"
    
    printf "%-25s %-10s %-15s %-15s\n" "Repository" "Registry" "Git Tag" "Status"
    echo "────────────────────────────────────────────────────────────"
    
    mapfile -t repos < <(yq eval '.repositories[].name' "${PROJECT_ROOT}/registry/repositories.yaml")
    
    for repo in "${repos[@]}"; do
        local full_name="caddycart-${repo}"
        local registry_version=$(get_version "$repo")
        local submodule_path="modules/${repo}"
        
        printf "%-25s %-10s " "$full_name" "v$registry_version"
        
        if [ -d "${PROJECT_ROOT}/${submodule_path}" ]; then
            cd "${PROJECT_ROOT}/${submodule_path}"
            
            local git_version=$(git describe --tags --abbrev=0 2>/dev/null || echo "no-tag")
            git_version=${git_version#v}
            
            printf "%-15s " "v$git_version"
            
            if [ "$registry_version" = "$git_version" ]; then
                printf "${GREEN}✓ Synced${NC}\n"
            else
                printf "${YELLOW}⚠ Mismatch${NC}\n"
            fi
            
            cd - > /dev/null
        else
            printf "%-15s ${RED}Not cloned${NC}\n" "-"
        fi
    done
    
    if [ ${#repos[@]} -eq 0 ]; then
        echo "No repositories registered."
    fi
}

main "$@"