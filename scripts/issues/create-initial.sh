#!/bin/bash
# Create initial issues and milestones for a new repository

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Create initial milestones
create_milestones() {
    local repo_name=$1
    local full_name="caddycart-${repo_name}"
    
    log_info "Creating milestones for ${full_name}..."
    
    # v0.1.0 - Foundation
    gh api \
        --method POST \
        "/repos/${GITHUB_USER}/${full_name}/milestones" \
        --field title="v0.1.0 - Foundation" \
        --field description="Initial foundation release with basic functionality" \
        --field due_on="$(date -d '+2 weeks' -Iseconds)" \
        2>/dev/null || log_warning "Milestone v0.1.0 already exists"
    
    # v0.2.0 - Core Features
    gh api \
        --method POST \
        "/repos/${GITHUB_USER}/${full_name}/milestones" \
        --field title="v0.2.0 - Core Features" \
        --field description="Core feature implementation" \
        --field due_on="$(date -d '+4 weeks' -Iseconds)" \
        2>/dev/null || log_warning "Milestone v0.2.0 already exists"
    
    # v1.0.0 - Production Ready
    gh api \
        --method POST \
        "/repos/${GITHUB_USER}/${full_name}/milestones" \
        --field title="v1.0.0 - Production Ready" \
        --field description="Production-ready release with full features" \
        --field due_on="$(date -d '+8 weeks' -Iseconds)" \
        2>/dev/null || log_warning "Milestone v1.0.0 already exists"
}

# Create type-specific issues
create_issues_for_type() {
    local repo_name=$1
    local repo_type=$2
    local full_name="caddycart-${repo_name}"
    
    log_info "Creating initial issues for ${full_name} (${repo_type})..."
    
    case $repo_type in
        core)
            create_core_issues "$repo_name"
            ;;
        service)
            create_service_issues "$repo_name"
            ;;
        application)
            create_application_issues "$repo_name"
            ;;
        infrastructure)
            create_infrastructure_issues "$repo_name"
            ;;
        tool)
            create_tool_issues "$repo_name"
            ;;
        documentation)
            create_documentation_issues "$repo_name"
            ;;
        *)
            create_generic_issues "$repo_name"
            ;;
    esac
}

# Create issues for core type repositories
create_core_issues() {
    local repo_name=$1
    local full_name="caddycart-${repo_name}"
    
    # Foundation issues
    gh issue create \
        --repo "${GITHUB_USER}/${full_name}" \
        --title "Define core domain models" \
        --body "Create the fundamental domain models and value objects" \
        --label "type:feature,priority:high" \
        --milestone "v0.1.0 - Foundation" \
        2>/dev/null || true
    
    gh issue create \
        --repo "${GITHUB_USER}/${full_name}" \
        --title "Implement validation logic" \
        --body "Add validation rules for domain models" \
        --label "type:feature,priority:high" \
        --milestone "v0.1.0 - Foundation" \
        2>/dev/null || true
    
    gh issue create \
        --repo "${GITHUB_USER}/${full_name}" \
        --title "Add unit tests" \
        --body "Create comprehensive unit tests for all models" \
        --label "type:test,priority:medium" \
        --milestone "v0.1.0 - Foundation" \
        2>/dev/null || true
    
    # Documentation
    gh issue create \
        --repo "${GITHUB_USER}/${full_name}" \
        --title "Document API interfaces" \
        --body "Create documentation for all public interfaces" \
        --label "type:documentation,priority:medium" \
        --milestone "v0.2.0 - Core Features" \
        2>/dev/null || true
}

# Create issues for service type repositories
create_service_issues() {
    local repo_name=$1
    local full_name="caddycart-${repo_name}"
    
    # Setup issues
    gh issue create \
        --repo "${GITHUB_USER}/${full_name}" \
        --title "Setup service framework" \
        --body "Initialize the service with chosen framework (Express/FastAPI/etc)" \
        --label "type:feature,priority:high" \
        --milestone "v0.1.0 - Foundation" \
        2>/dev/null || true
    
    gh issue create \
        --repo "${GITHUB_USER}/${full_name}" \
        --title "Define API endpoints" \
        --body "Create RESTful API endpoints with OpenAPI documentation" \
        --label "type:feature,priority:high" \
        --milestone "v0.1.0 - Foundation" \
        2>/dev/null || true
    
    gh issue create \
        --repo "${GITHUB_USER}/${full_name}" \
        --title "Implement authentication" \
        --body "Add authentication and authorization middleware" \
        --label "type:feature,priority:high,scope:auth" \
        --milestone "v0.2.0 - Core Features" \
        2>/dev/null || true
    
    gh issue create \
        --repo "${GITHUB_USER}/${full_name}" \
        --title "Add database integration" \
        --body "Connect to database and implement repositories" \
        --label "type:feature,priority:medium,scope:database" \
        --milestone "v0.2.0 - Core Features" \
        2>/dev/null || true
    
    gh issue create \
        --repo "${GITHUB_USER}/${full_name}" \
        --title "Setup monitoring and logging" \
        --body "Add structured logging and monitoring endpoints" \
        --label "type:feature,priority:medium" \
        --milestone "v0.2.0 - Core Features" \
        2>/dev/null || true
}

# Create issues for application type repositories
create_application_issues() {
    local repo_name=$1
    local full_name="caddycart-${repo_name}"
    
    gh issue create \
        --repo "${GITHUB_USER}/${full_name}" \
        --title "Setup application framework" \
        --body "Initialize the application with chosen framework" \
        --label "type:feature,priority:high" \
        --milestone "v0.1.0 - Foundation" \
        2>/dev/null || true
    
    gh issue create \
        --repo "${GITHUB_USER}/${full_name}" \
        --title "Create UI components" \
        --body "Build reusable UI components" \
        --label "type:feature,priority:high,scope:ui" \
        --milestone "v0.1.0 - Foundation" \
        2>/dev/null || true
    
    gh issue create \
        --repo "${GITHUB_USER}/${full_name}" \
        --title "Implement routing" \
        --body "Setup application routing and navigation" \
        --label "type:feature,priority:high" \
        --milestone "v0.1.0 - Foundation" \
        2>/dev/null || true
    
    gh issue create \
        --repo "${GITHUB_USER}/${full_name}" \
        --title "Add state management" \
        --body "Implement state management solution" \
        --label "type:feature,priority:medium" \
        --milestone "v0.2.0 - Core Features" \
        2>/dev/null || true
}

# Create issues for infrastructure type repositories
create_infrastructure_issues() {
    local repo_name=$1
    local full_name="caddycart-${repo_name}"
    
    gh issue create \
        --repo "${GITHUB_USER}/${full_name}" \
        --title "Define infrastructure as code" \
        --body "Create Terraform/CloudFormation templates" \
        --label "type:feature,priority:high,scope:infrastructure" \
        --milestone "v0.1.0 - Foundation" \
        2>/dev/null || true
    
    gh issue create \
        --repo "${GITHUB_USER}/${full_name}" \
        --title "Setup CI/CD pipelines" \
        --body "Create deployment pipelines for all services" \
        --label "type:feature,priority:high" \
        --milestone "v0.1.0 - Foundation" \
        2>/dev/null || true
    
    gh issue create \
        --repo "${GITHUB_USER}/${full_name}" \
        --title "Configure monitoring" \
        --body "Setup monitoring and alerting infrastructure" \
        --label "type:feature,priority:medium" \
        --milestone "v0.2.0 - Core Features" \
        2>/dev/null || true
}

# Create issues for tool type repositories
create_tool_issues() {
    local repo_name=$1
    local full_name="caddycart-${repo_name}"
    
    gh issue create \
        --repo "${GITHUB_USER}/${full_name}" \
        --title "Implement core functionality" \
        --body "Build the main tool functionality" \
        --label "type:feature,priority:high" \
        --milestone "v0.1.0 - Foundation" \
        2>/dev/null || true
    
    gh issue create \
        --repo "${GITHUB_USER}/${full_name}" \
        --title "Add CLI interface" \
        --body "Create command-line interface if applicable" \
        --label "type:feature,priority:medium" \
        --milestone "v0.2.0 - Core Features" \
        2>/dev/null || true
}

# Create issues for documentation type repositories
create_documentation_issues() {
    local repo_name=$1
    local full_name="caddycart-${repo_name}"
    
    gh issue create \
        --repo "${GITHUB_USER}/${full_name}" \
        --title "Create documentation structure" \
        --body "Setup documentation framework and structure" \
        --label "type:documentation,priority:high" \
        --milestone "v0.1.0 - Foundation" \
        2>/dev/null || true
    
    gh issue create \
        --repo "${GITHUB_USER}/${full_name}" \
        --title "Write getting started guide" \
        --body "Create comprehensive getting started documentation" \
        --label "type:documentation,priority:high" \
        --milestone "v0.1.0 - Foundation" \
        2>/dev/null || true
}

# Create generic issues for unknown types
create_generic_issues() {
    local repo_name=$1
    local full_name="caddycart-${repo_name}"
    
    gh issue create \
        --repo "${GITHUB_USER}/${full_name}" \
        --title "Initial setup" \
        --body "Setup repository structure and dependencies" \
        --label "type:feature,priority:high" \
        --milestone "v0.1.0 - Foundation" \
        2>/dev/null || true
    
    gh issue create \
        --repo "${GITHUB_USER}/${full_name}" \
        --title "Add tests" \
        --body "Create test suite" \
        --label "type:test,priority:medium" \
        --milestone "v0.1.0 - Foundation" \
        2>/dev/null || true
    
    gh issue create \
        --repo "${GITHUB_USER}/${full_name}" \
        --title "Add documentation" \
        --body "Document functionality and usage" \
        --label "type:documentation,priority:medium" \
        --milestone "v0.2.0 - Core Features" \
        2>/dev/null || true
}

# Main execution
main() {
    local repo_name=${1:-}
    local repo_type=${2:-}
    
    if [ -z "$repo_name" ]; then
        echo "Usage: $0 <repo-name> [repo-type]"
        exit 1
    fi
    
    # Get type from registry if not provided
    if [ -z "$repo_type" ]; then
        repo_type=$(get_repo_info "$repo_name" "type")
    fi
    
    GITHUB_USER=$(yq eval '.project.owner' "${PROJECT_ROOT}/config/orchestration.yaml")
    
    create_milestones "$repo_name"
    create_issues_for_type "$repo_name" "$repo_type"
    
    log_success "Initial issues and milestones created for ${repo_name}"
}

main "$@"