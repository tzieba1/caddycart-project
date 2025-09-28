#!/bin/bash
# Synchronize issues and milestones across repositories

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Create milestone in all repositories
create_global_milestone() {
    local title=$1
    local description=$2
    local due_date=$3
    
    log_info "Creating milestone: ${title}"
    
    # Get all repositories
    mapfile -t repos < <(list_repositories)
    
    for repo in "${repos[@]}"; do
        local full_name="caddycart-${repo}"
        
        log_info "  Creating in ${full_name}..."
        
        gh api \
            --method POST \
            "/repos/${GITHUB_USER}/${full_name}/milestones" \
            --field title="${title}" \
            --field description="${description}" \
            --field due_on="${due_date}" \
            2>/dev/null || log_warning "    Already exists or error"
    done
    
    log_success "Milestone created in all repositories"
}

# Create cross-repository issue
create_cross_repo_issue() {
    local title=$1
    local body=$2
    local repos=$3  # comma-separated
    local labels=${4:-""}
    local milestone=${5:-""}
    
    log_info "Creating cross-repository issue: ${title}"
    
    # Parse repositories
    IFS=',' read -ra repo_list <<< "$repos"
    
    local issue_urls=()
    
    for repo in "${repo_list[@]}"; do
        repo=$(echo "$repo" | xargs)
        local full_name="caddycart-${repo}"
        
        log_info "  Creating in ${full_name}..."
        
        # Create issue
        local issue_url=$(gh issue create \
            --repo "${GITHUB_USER}/${full_name}" \
            --title "${title}" \
            --body "${body}" \
            --label "${labels}" \
            --milestone "${milestone}" \
            2>/dev/null | tail -1)
        
        issue_urls+=("$issue_url")
    done
    
    # Update issues with cross-references
    log_info "Adding cross-references..."
    
    local references="## Related Issues\n"
    for url in "${issue_urls[@]}"; do
        references="${references}- ${url}\n"
    done
    
    for url in "${issue_urls[@]}"; do
        # Extract repo and issue number from URL
        local repo_issue=$(echo "$url" | sed 's|.*/\([^/]*\)/issues/\([0-9]*\)$|\1 \2|')
        read -r repo_name issue_num <<< "$repo_issue"
        
        # Add cross-references as comment
        gh issue comment "$issue_num" \
            --repo "${GITHUB_USER}/${repo_name}" \
            --body "$(echo -e "$references")"
    done
    
    log_success "Cross-repository issue created"
}

# Sync labels across repositories
sync_labels() {
    log_info "Syncing labels across repositories"
    
    local labels_file="${PROJECT_ROOT}/config/labels.yaml"
    
    if [ ! -f "$labels_file" ]; then
        log_warning "Labels file not found, creating default..."
        create_default_labels_file
    fi
    
    # Get all repositories
    mapfile -t repos < <(list_repositories)
    
    for repo in "${repos[@]}"; do
        local full_name="caddycart-${repo}"
        
        log_info "  Syncing labels to ${full_name}..."
        
        # Delete existing labels (optional)
        # gh label delete --repo "${GITHUB_USER}/${full_name}" --all
        
        # Create labels from file
        yq eval '.labels[]' "$labels_file" | \
        yq eval -o=json | jq -r '"\(.name)|\(.color)|\(.description)"' | \
        while IFS='|' read -r name color description; do
            gh label create "$name" \
                --repo "${GITHUB_USER}/${full_name}" \
                --color "$color" \
                --description "$description" \
                --force 2>/dev/null || true
        done
    done
    
    log_success "Labels synchronized"
}

# Create default labels file
create_default_labels_file() {
    cat > "${PROJECT_ROOT}/config/labels.yaml" << 'EOF'
labels:
  # Types
  - name: "type:feature"
    color: "0052cc"
    description: "New feature or enhancement"
  - name: "type:bug"
    color: "d73a4a"
    description: "Something isn't working"
  - name: "type:documentation"
    color: "0075ca"
    description: "Documentation improvements"
  - name: "type:maintenance"
    color: "ffd93d"
    description: "Maintenance and chores"
    
  # Priority
  - name: "priority:critical"
    color: "b60205"
    description: "Critical priority"
  - name: "priority:high"
    color: "ff6b6b"
    description: "High priority"
  - name: "priority:medium"
    color: "fbca04"
    description: "Medium priority"
  - name: "priority:low"
    color: "0e8a16"
    description: "Low priority"
    
  # Status
  - name: "status:blocked"
    color: "d73a4a"
    description: "Blocked by another issue"
  - name: "status:in-progress"
    color: "fbca04"
    description: "Work in progress"
  - name: "status:review"
    color: "0052cc"
    description: "In review"
    
  # Scope
  - name: "scope:core"
    color: "5319e7"
    description: "Core functionality"
  - name: "scope:api"
    color: "5319e7"
    description: "API related"
  - name: "scope:ui"
    color: "5319e7"
    description: "User interface"
  - name: "scope:infrastructure"
    color: "5319e7"
    description: "Infrastructure and DevOps"
    
  # Special
  - name: "good-first-issue"
    color: "7057ff"
    description: "Good for newcomers"
  - name: "help-wanted"
    color: "008672"
    description: "Extra attention needed"
  - name: "breaking-change"
    color: "d73a4a"
    description: "Breaking change"
  - name: "dependencies"
    color: "0366d6"
    description: "Dependency updates"
EOF
}

# Main execution
main() {
    ACTION=${1:-sync}
    
    case $ACTION in
        milestone)
            TITLE=${2:-}
            DESCRIPTION=${3:-}
            DUE_DATE=${4:-}
            
            if [ -z "$TITLE" ]; then
                echo "Usage: $0 milestone <title> <description> <due-date>"
                exit 1
            fi
            
            create_global_milestone "$TITLE" "$DESCRIPTION" "$DUE_DATE"
            ;;
            
        issue)
            TITLE=${2:-}
            BODY=${3:-}
            REPOS=${4:-}
            
            if [ -z "$TITLE" ] || [ -z "$REPOS" ]; then
                echo "Usage: $0 issue <title> <body> <repos>"
                echo "Example: $0 issue 'Security Update' 'Update all dependencies' 'core,api,web'"
                exit 1
            fi
            
            create_cross_repo_issue "$TITLE" "$BODY" "$REPOS"
            ;;
            
        labels|sync)
            sync_labels
            ;;
            
        *)
            echo "Usage: $0 {milestone|issue|labels|sync}"
            exit 1
            ;;
    esac
}

main "$@"