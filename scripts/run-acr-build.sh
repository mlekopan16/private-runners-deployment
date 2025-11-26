#!/bin/bash

# ACR Build Script
# Trigger ACR Task to build and push GitHub Actions runner image to Azure Container Registry
# This script performs cloud-based builds - no local Docker required

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Default values
ACR_NAME=""
TASK_NAME="build-github-runner"
IMAGE_NAME="github-runner"
IMAGE_TAG="latest"
DOCKERFILE_PATH="docker/Dockerfile"
CONTEXT_PATH="docker"
GIT_REPO_URL=""
GIT_BRANCH="main"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --acr-name)
            ACR_NAME="$2"
            shift 2
            ;;
        --task-name)
            TASK_NAME="$2"
            shift 2
            ;;
        --image-name)
            IMAGE_NAME="$2"
            shift 2
            ;;
        --image-tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        --dockerfile-path)
            DOCKERFILE_PATH="$2"
            shift 2
            ;;
        --context-path)
            CONTEXT_PATH="$2"
            shift 2
            ;;
        --git-repo-url)
            GIT_REPO_URL="$2"
            shift 2
            ;;
        --git-branch)
            GIT_BRANCH="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 --acr-name <acr-name> [OPTIONS]"
            echo ""
            echo "Required:"
            echo "  --acr-name NAME          Azure Container Registry name"
            echo ""
            echo "Optional:"
            echo "  --task-name NAME         ACR Task name (default: build-github-runner)"
            echo "  --image-name NAME        Image name (default: github-runner)"
            echo "  --image-tag TAG          Image tag (default: latest)"
            echo "  --dockerfile-path PATH   Dockerfile path (default: docker/Dockerfile)"
            echo "  --context-path PATH      Build context path (default: docker)"
            echo "  --git-repo-url URL       Git repository URL for remote context"
            echo "  --git-branch BRANCH      Git branch (default: main)"
            echo "  -h, --help               Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 --acr-name myacr"
            echo "  $0 --acr-name myacr --image-tag v1.0.0"
            echo "  $0 --acr-name myacr --git-repo-url https://github.com/user/repo --git-branch develop"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$ACR_NAME" ]; then
    print_error "ACR name is required"
    echo "Use: $0 --acr-name <acr-name>"
    echo "Use -h or --help for more information"
    exit 1
fi

print_success "Starting ACR Task build..."
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed"
    echo "Please install Azure CLI from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check Azure authentication
if ! az account show &> /dev/null; then
    print_warning "Not logged in to Azure. Please log in:"
    if ! az login; then
        print_error "Failed to log in to Azure"
        exit 1
    fi
fi

print_success "Authenticated to Azure"

# Get ACR login server
print_info "Getting ACR login server..."
ACR_LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer --output tsv 2>/dev/null)

if [ -z "$ACR_LOGIN_SERVER" ]; then
    print_error "Failed to get ACR login server. Please check ACR name: $ACR_NAME"
    exit 1
fi

FULL_IMAGE_NAME="$ACR_LOGIN_SERVER/$IMAGE_NAME:$IMAGE_TAG"

echo ""
print_info "ACR Configuration:"
echo "  Registry: $ACR_NAME"
echo "  Login Server: $ACR_LOGIN_SERVER"
echo "  Task Name: $TASK_NAME"
echo "  Image: $FULL_IMAGE_NAME"
echo "  Dockerfile: $DOCKERFILE_PATH"
echo "  Context: $CONTEXT_PATH"
echo ""


# Determine build method based on whether Git repo URL is provided
if [ -n "$GIT_REPO_URL" ]; then
    # Git-based build requires ACR Task
    print_info "Checking if ACR Task exists for Git-based builds..."
    if ! az acr task show --name "$TASK_NAME" --registry "$ACR_NAME" --output none 2>/dev/null; then
        print_error "ACR Task '$TASK_NAME' not found in registry '$ACR_NAME'"
        print_info "Git-based builds require an ACR Task. Please set enable_git_trigger=true in Terraform"
        print_info "Or use local build by omitting --git-repo-url"
        exit 1
    fi
    
    print_success "ACR Task found"
    echo ""
    print_info "Triggering ACR Task build with Git repository: $GIT_REPO_URL (branch: $GIT_BRANCH)"
    
    if ! az acr task run \
        --name "$TASK_NAME" \
        --registry "$ACR_NAME" \
        --context "$GIT_REPO_URL#$GIT_BRANCH:$CONTEXT_PATH" \
        --file "$DOCKERFILE_PATH"; then
        print_error "ACR Task build failed"
        exit 1
    fi
else
    # Local build using az acr build (no ACR Task needed)
    print_info "Using local build context (no ACR Task required)"
    echo ""
    print_info "Building image using 'az acr build'..."
    
    # Determine the repository root
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    
    CONTEXT_FULL_PATH="$REPO_ROOT/$CONTEXT_PATH"
    DOCKERFILE_FULL_PATH="$REPO_ROOT/$DOCKERFILE_PATH"
    
    # Check if context path exists
    if [ ! -d "$CONTEXT_FULL_PATH" ]; then
        print_error "Build context path not found: $CONTEXT_FULL_PATH"
        exit 1
    fi
    
    # Check if Dockerfile exists
    if [ ! -f "$DOCKERFILE_FULL_PATH" ]; then
        print_error "Dockerfile not found: $DOCKERFILE_FULL_PATH"
        exit 1
    fi
    
    print_info "Context: $CONTEXT_FULL_PATH"
    print_info "Dockerfile: $DOCKERFILE_FULL_PATH"
    echo ""
    
    if ! az acr build \
        --registry "$ACR_NAME" \
        --image "$IMAGE_NAME:$IMAGE_TAG" \
        --file "$DOCKERFILE_FULL_PATH" \
        "$CONTEXT_FULL_PATH"; then
        print_error "ACR build failed"
        exit 1
    fi
fi

print_success "ACR build completed successfully!"
echo ""
print_info "Built image: $FULL_IMAGE_NAME"

# Verify the image was pushed
echo ""
print_info "Verifying image in ACR..."
if az acr repository show-tags --name "$ACR_NAME" --repository "$IMAGE_NAME" --output tsv &> /dev/null; then
    print_success "Image successfully pushed to ACR"
    
    echo ""
    print_info "Image details:"
    az acr repository show-tags --name "$ACR_NAME" --repository "$IMAGE_NAME" --detail --output table
else
    print_error "Failed to verify image in ACR"
    exit 1
fi

# Export image reference
IMAGE_REFERENCE_FILE="$REPO_ROOT/.image-reference"
echo "GITHUB_RUNNER_IMAGE=$FULL_IMAGE_NAME" > "$IMAGE_REFERENCE_FILE"

echo ""
print_success "Build and push completed successfully!"
echo ""
print_info "Image reference saved to .image-reference file"
print_info "You can use this image reference in your Terraform configuration"
echo ""
print_info "Next steps:"
echo "  1. The Container Apps Job will automatically use this image"
echo "  2. Trigger the job: az containerapp job start --name <job-name> --resource-group <rg-name>"
echo "  3. Verify runner in GitHub: Settings → Actions → Runners"
