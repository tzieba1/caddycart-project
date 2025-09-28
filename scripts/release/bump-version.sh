#!/bin/bash
# Bump version for a specific repository or all repositories

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Bump version for a single repository
bump_repository_version() {
    local repo_name=$1
    local bump_type=$2  # major|minor|patch|auto
    
    local submodule_path="modules/${repo_name}"
    
    if [ ! -d "${PROJECT_ROOT}/${submodule_path}" ]; then
        log_error "Repository ${repo_name} not found"
        return 1
    fi
    
    cd "${PROJECT_ROOT}/${submodule_path}"
    
    # Get current version
    local current_version=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
    current_version=${current_version#v}
    
    log_info "Current version of ${repo_name}: ${current_version}"
    
    # Parse version components
    IFS='.' read -r major minor patch <<< "$current_version"
    
    # Auto-detect bump type from commits if requested
    if [ "$bump_type" == "auto" ]; then
        bump_type=$(detect_bump_type)
        log_info "Auto-detected bump type: ${bump_type}"
    fi
    
    # Calculate new version
    case $bump_type in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            log_error "Invalid bump type: ${bump_type}"
            return 1
            ;;
    esac
    
    local new_version="${major}.${minor}.${patch}"
    
    log_info "Bumping ${repo_name} to v${new_version}"
    
    # Update version in files
    update_version_in_files "$new_version"
    
    # Commit and tag
    git add -A
    git commit -m "chore: bump version to ${new_version}

- Previous version: ${current_version}
- Bump type: ${bump_type}
- Automated version bump" || true
    
    git tag -a "v${new_version}" -m "Version ${new_version}

Bump type: ${bump_type}
Previous version: ${current_version}"
    
    # Update registry
    cd "${PROJECT_ROOT}"
    update_version "$repo_name" "$new_version"
    
    log_success "Bumped ${repo_name} to v${new_version}"
    
    return 0
}

# Detect bump type from conventional commits
detect_bump_type() {
    local last_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    local commit_range
    
    if [ -n "$last_tag" ]; then
        commit_range="${last_tag}..HEAD"
    else
        commit_range="HEAD"
    fi
    
    # Check for breaking changes
    if git log $commit_range --grep="BREAKING CHANGE" --grep="!:" | grep -q .; then
        echo "major"
        return
    fi
    
    # Check for features
    if git log $commit_range --grep="^feat" | grep -q .; then
        echo "minor"
        return
    fi
    
    # Check for fixes
    if git log $commit_range --grep="^fix" --grep="^perf" | grep -q .; then
        echo "patch"
        return
    fi
    
    # Default to patch
    echo "patch"
}

# Update version in various files
update_version_in_files() {
    local version=$1
    
    # Update package.json
    if [ -f "package.json" ]; then
        if command -v npm &> /dev/null; then
            npm version "$version" --no-git-tag-version
        else
            # Manual update with sed
            sed -i.bak "s/\"version\": \"[^\"]*\"/\"version\": \"${version}\"/" package.json
            rm -f package.json.bak
        fi
    fi
    
    # Update VERSION file
    echo "$version" > VERSION
    
    # Update Cargo.toml
    if [ -f "Cargo.toml" ]; then
        sed -i.bak "s/^version = \"[^\"]*\"/version = \"${version}\"/" Cargo.toml
        rm -f Cargo.toml.bak
    fi
    
    # Update pyproject.toml
    if [ -f "pyproject.toml" ]; then
        sed -i.bak "s/^version = \"[^\"]*\"/version = \"${version}\"/" pyproject.toml
        rm -f pyproject.toml.bak
    fi
    
    # Update Chart.yaml (Helm)
    if [ -f "Chart.yaml" ]; then
        sed -i.bak "s/^version: .*/version: ${version}/" Chart.yaml
        rm -f Chart.yaml.bak
    fi
}

# Main execution
main() {
    cd "${PROJECT_ROOT}"
    
    REPO_NAME=${1:-}
    BUMP_TYPE=${2:-auto}
    
    if [ -z "$REPO_NAME" ]; then
        echo "Usage: $0 <repo-name> [bump-type]"
        echo ""
        echo "Bump types:"
        echo "  - major: Breaking changes (1.0.0 -> 2.0.0)"
        echo "  - minor: New features (1.0.0 -> 1.1.0)"
        echo "  - patch: Bug fixes (1.0.0 -> 1.0.1)"
        echo "  - auto: Detect from commits (default)"
        echo ""
        echo "Examples:"
        echo "  $0 contracts minor"
        echo "  $0 api auto"
        exit 1
    fi
    
    bump_repository_version "$REPO_NAME" "$BUMP_TYPE"
}

main "$@"