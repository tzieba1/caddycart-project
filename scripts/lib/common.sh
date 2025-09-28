#!/bin/bash
# Common functions library

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_header() { 
    echo -e "${BOLD}$*${NC}"
    echo "═══════════════════════════════════════════════════════"
}

# Check if repository exists
repo_exists() {
    local repo_name=$1
    yq eval ".repositories[] | select(.name == \"$repo_name\")" \
        "${PROJECT_ROOT}/registry/repositories.yaml" | grep -q "name"
}

# Get repository info
get_repo_info() {
    local repo_name=$1
    local field=$2
    yq eval ".repositories[] | select(.name == \"$repo_name\") | .${field}" \
        "${PROJECT_ROOT}/registry/repositories.yaml"
}

# Register repository in registry
register_repository() {
    local name=$1
    local type=$2
    local description=$3
    local dependencies=$4
    local version=$5
    
    local full_name="caddycart-${name}"
    local timestamp=$(date -I)
    
    # Add to registry
    yq eval -i ".repositories += [{
        \"name\": \"${name}\",
        \"full_name\": \"${full_name}\",
        \"type\": \"${type}\",
        \"created\": \"${timestamp}\",
        \"version\": \"${version}\",
        \"status\": \"active\",
        \"dependencies\": [$(echo "$dependencies" | sed 's/,/","/g' | sed 's/^/"/;s/$/"/;s/""//')],
        \"dependents\": [],
        \"submodule_path\": \"modules/${name}\",
        \"github_url\": \"https://github.com/${GITHUB_USER}/${full_name}\",
        \"description\": \"${description}\"
    }]" "${PROJECT_ROOT}/registry/repositories.yaml"
}

# List all repositories
list_repositories() {
    yq eval '.repositories[].name' "${PROJECT_ROOT}/registry/repositories.yaml"
}

# Get repository version
get_version() {
    local repo_name=$1
    get_repo_info "$repo_name" "version"
}

# Update repository version
update_version() {
    local repo_name=$1
    local new_version=$2
    
    yq eval -i "(.repositories[] | select(.name == \"$repo_name\") | .version) = \"$new_version\"" \
        "${PROJECT_ROOT}/registry/repositories.yaml"
}