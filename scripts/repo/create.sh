#!/bin/bash
# Guided repository creation with dependency management

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${PROJECT_ROOT}/scripts/lib/common.sh"
source "${PROJECT_ROOT}/scripts/lib/dependencies.sh"

# Interactive repository creation
create_repository_interactive() {
    log_header "CaddyCart Repository Creation Wizard"
    
    # Step 1: Repository name
    echo ""
    read -p "Repository name (without caddycart- prefix): " REPO_NAME
    
    if [ -z "$REPO_NAME" ]; then
        log_error "Repository name is required"
        exit 1
    fi
    
    FULL_REPO_NAME="caddycart-${REPO_NAME}"
    
    # Check if already exists
    if repo_exists "$REPO_NAME"; then
        log_error "Repository ${FULL_REPO_NAME} already exists"
        exit 1
    fi
    
    # Step 2: Repository type
    echo ""
    echo "Repository types:"
    echo "  1) core        - Core business logic or shared libraries"
    echo "  2) service     - Microservice or API service"
    echo "  3) application - User-facing application"
    echo "  4) infrastructure - Infrastructure or DevOps"
    echo "  5) tool        - Development tools or utilities"
    echo "  6) documentation - Documentation or guides"
    echo ""
    read -p "Select type (1-6): " TYPE_CHOICE
    
    case $TYPE_CHOICE in
        1) REPO_TYPE="core";;
        2) REPO_TYPE="service";;
        3) REPO_TYPE="application";;
        4) REPO_TYPE="infrastructure";;
        5) REPO_TYPE="tool";;
        6) REPO_TYPE="documentation";;
        *) log_error "Invalid choice"; exit 1;;
    esac
    
    # Step 3: Description
    echo ""
    read -p "Repository description: " REPO_DESC
    
    # Step 4: Dependencies
    echo ""
    echo "Dependencies Selection"
    echo "======================"
    
    # Get allowed dependencies for this type
    ALLOWED_DEPS=$(get_allowed_dependencies "$REPO_TYPE")
    
    if [ "$ALLOWED_DEPS" == "none" ]; then
        echo "This repository type cannot have dependencies."
        DEPENDENCIES=""
    else
        echo "This repository can depend on types: $ALLOWED_DEPS"
        echo ""
        echo "Available repositories:"
        list_available_dependencies "$REPO_TYPE"
        echo ""
        echo "Enter dependencies (comma-separated, e.g., contracts,auth):"
        read -p "Dependencies (or press Enter for none): " DEPENDENCIES
    fi
    
    # Step 5: Initial version
    echo ""
    read -p "Initial version (default: 0.1.0): " INITIAL_VERSION
    INITIAL_VERSION=${INITIAL_VERSION:-0.1.0}
    
    # Step 6: Visibility
    echo ""
    read -p "Repository visibility (private/public) [private]: " VISIBILITY
    VISIBILITY=${VISIBILITY:-private}
    
    # Step 7: Confirmation
    echo ""
    log_info "Repository Configuration:"
    echo "  Name: ${FULL_REPO_NAME}"
    echo "  Type: ${REPO_TYPE}"
    echo "  Description: ${REPO_DESC}"
    echo "  Dependencies: ${DEPENDENCIES:-none}"
    echo "  Version: ${INITIAL_VERSION}"
    echo "  Visibility: ${VISIBILITY}"
    echo ""
    read -p "Create repository? (y/n): " CONFIRM
    
    if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
        log_warning "Repository creation cancelled"
        exit 0
    fi
    
    # Create repository
    create_repository \
        "$REPO_NAME" \
        "$REPO_TYPE" \
        "$REPO_DESC" \
        "$DEPENDENCIES" \
        "$INITIAL_VERSION" \
        "$VISIBILITY"
}

# Create repository with all configuration
create_repository() {
    local name=$1
    local type=$2
    local description=$3
    local dependencies=$4
    local version=$5
    local visibility=$6
    
    local full_name="caddycart-${name}"
    local submodule_path="modules/${name}"
    
    log_info "Creating repository ${full_name}..."
    
    # Create GitHub repository
    gh repo create "${full_name}" \
        --${visibility} \
        --description "${description}" \
        --clone=false \
        2>/dev/null || log_warning "GitHub repo already exists"
    
    # Clone as submodule
    git submodule add \
        "git@github.com:${GITHUB_USER}/${full_name}.git" \
        "${submodule_path}" \
        2>/dev/null || log_warning "Submodule already exists"
    
    # Initialize repository from template
    initialize_repository_from_template \
        "$name" \
        "$type" \
        "$description" \
        "$dependencies" \
        "$version"
    
    # Register repository
    register_repository \
        "$name" \
        "$type" \
        "$description" \
        "$dependencies" \
        "$version"
    
    # Update dependency graph
    update_dependency_graph "$name" "$dependencies"
    
    # Create initial issues and milestones
    create_initial_issues "$name" "$type"
    
    # Commit changes to meta repository
    git add .
    git commit -m "feat: add ${full_name} repository

- Type: ${type}
- Dependencies: ${dependencies:-none}
- Initial version: ${version}"
    
    log_success "Repository ${full_name} created successfully!"
    
    echo ""
    echo "Next steps:"
    echo "  1. cd ${submodule_path}"
    echo "  2. Implement initial features"
    echo "  3. Create issues for v${version}"
    echo "  4. Push changes"
}

# Initialize repository from template
initialize_repository_from_template() {
    local name=$1
    local type=$2
    local description=$3
    local dependencies=$4
    local version=$5
    
    local full_name="caddycart-${name}"
    local submodule_path="modules/${name}"
    local template_path="${PROJECT_ROOT}/templates/repo/${type}"
    
    cd "${PROJECT_ROOT}/${submodule_path}"
    
    # Copy template files
    if [ -d "$template_path" ]; then
        cp -r "${template_path}"/. .
    else
        # Use generic template
        cp -r "${PROJECT_ROOT}/templates/repo/generic"/. .
    fi
    
    # Substitute variables in templates
    find . -type f -name "*.template" | while read -r template_file; do
        output_file="${template_file%.template}"
        sed \
            -e "s|{{REPO_NAME}}|${name}|g" \
            -e "s|{{FULL_REPO_NAME}}|${full_name}|g" \
            -e "s|{{REPO_TYPE}}|${type}|g" \
            -e "s|{{REPO_DESCRIPTION}}|${description}|g" \
            -e "s|{{DEPENDENCIES}}|${dependencies}|g" \
            -e "s|{{VERSION}}|${version}|g" \
            -e "s|{{GITHUB_USER}}|${GITHUB_USER}|g" \
            "$template_file" > "$output_file"
        rm "$template_file"
    done
    
    # Create dependency configuration
    if [ -n "$dependencies" ]; then
        create_dependency_config "$name" "$dependencies"
    fi
    
    # Initial commit
    git add .
    git commit -m "feat: initialize ${name} repository

- Repository type: ${type}
- Dependencies: ${dependencies:-none}
- Initial version: ${version}
- Generated from template"
    
    # Create initial tag
    git tag -a "v${version}" -m "Initial version ${version}"
    
    # Push to GitHub
    git push -u origin main
    git push --tags
    
    cd "${PROJECT_ROOT}"
}

# Main execution
main() {
    cd "${PROJECT_ROOT}"
    
    # Load configuration
    GITHUB_USER=$(yq eval '.project.owner' config/orchestration.yaml)
    
    if [ $# -eq 0 ]; then
        # Interactive mode
        create_repository_interactive
    else
        # CLI mode
        while [[ $# -gt 0 ]]; do
            case $1 in
                --name) REPO_NAME="$2"; shift 2;;
                --type) REPO_TYPE="$2"; shift 2;;
                --desc) REPO_DESC="$2"; shift 2;;
                --deps) DEPENDENCIES="$2"; shift 2;;
                --version) INITIAL_VERSION="$2"; shift 2;;
                --visibility) VISIBILITY="$2"; shift 2;;
                *) log_error "Unknown option: $1"; exit 1;;
            esac
        done
        
        create_repository \
            "${REPO_NAME}" \
            "${REPO_TYPE}" \
            "${REPO_DESC:-}" \
            "${DEPENDENCIES:-}" \
            "${INITIAL_VERSION:-0.1.0}" \
            "${VISIBILITY:-private}"
    fi
}

main "$@"