#!/bin/bash

# Complete Deployment Script for GitHub Runner on Azure Container Apps
# This script automates the entire deployment process:
# 1. Deploy base infrastructure (ACR, Container Apps Environment, etc.)
# 2. Build and push the GitHub runner Docker image
# 3. Deploy the Container Apps Job
# 4. Optionally trigger the job

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

print_step() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Parse command line arguments
GITHUB_PAT=""
TRIGGER_JOB=false
AUTO_APPROVE=false
SKIP_IMAGE_BUILD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --github-pat)
            GITHUB_PAT="$2"
            shift 2
            ;;
        --trigger-job)
            TRIGGER_JOB=true
            shift
            ;;
        --auto-approve)
            AUTO_APPROVE=true
            shift
            ;;
        --skip-image-build)
            SKIP_IMAGE_BUILD=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --github-pat TOKEN      GitHub PAT for runner registration (required)"
            echo "  --trigger-job           Trigger the Container Apps Job after deployment"
            echo "  --auto-approve          Skip Terraform approval prompts"
            echo "  --skip-image-build      Skip Docker image build (use if image already exists)"
            echo "  -h, --help              Show this help message"
            echo ""
            echo "Example:"
            echo "  $0 --github-pat ghp_xxxxxxxxxxxx --trigger-job"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Validate GitHub PAT
if [ -z "$GITHUB_PAT" ]; then
    # Check environment variable
    if [ -n "$GITHUB_PAT_ENV" ]; then
        GITHUB_PAT="$GITHUB_PAT_ENV"
    elif [ -n "$TF_VAR_github_pat" ]; then
        GITHUB_PAT="$TF_VAR_github_pat"
    else
        print_error "GitHub PAT is required"
        echo "You can provide it in one of three ways:"
        echo "  1. Command line: $0 --github-pat <token>"
        echo "  2. Environment variable: export GITHUB_PAT_ENV=<token>"
        echo "  3. Terraform variable: export TF_VAR_github_pat=<token>"
        echo ""
        echo "Use -h or --help for more information"
        exit 1
    fi
fi

# Determine script directory and repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo ""
print_step "GitHub Runner on Azure Container Apps - Complete Deployment"
echo ""
print_info "This script will:"
echo "  1. Deploy base infrastructure (ACR, Container Apps Environment, Log Analytics)"
echo "  2. Build and push GitHub runner Docker image to ACR"
echo "  3. Deploy Container Apps Job with the runner"
if [ "$TRIGGER_JOB" = true ]; then
    echo "  4. Trigger the Container Apps Job to start a runner"
fi
echo ""

# Check prerequisites
print_info "Checking prerequisites..."

if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed"
    echo "Please install Terraform from: https://www.terraform.io/downloads.html"
    exit 1
fi

if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed"
    echo "Please install Azure CLI from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

if ! az account show &> /dev/null; then
    print_error "Not logged in to Azure"
    echo "Please run: az login"
    exit 1
fi

print_success "All prerequisites met"

# Get Azure subscription info
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
export ARM_SUBSCRIPTION_ID="$SUBSCRIPTION_ID"

echo ""
print_info "Using Azure subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"

# Check if terraform.tfvars exists
if [ ! -f "$REPO_ROOT/terraform/terraform.tfvars" ]; then
    print_error "terraform.tfvars not found"
    echo "Please create terraform/terraform.tfvars from terraform/terraform.tfvars.example"
    exit 1
fi

# Extract ACR name from terraform.tfvars
ACR_NAME=$(grep '^acr_name' "$REPO_ROOT/terraform/terraform.tfvars" | sed 's/.*=\s*"\(.*\)".*/\1/' | tr -d ' ')
RESOURCE_GROUP=$(grep '^resource_group_name' "$REPO_ROOT/terraform/terraform.tfvars" | sed 's/.*=\s*"\(.*\)".*/\1/' | tr -d ' ')
JOB_NAME=$(grep '^github_runner_job_name' "$REPO_ROOT/terraform/terraform.tfvars" | sed 's/.*=\s*"\(.*\)".*/\1/' | tr -d ' ')

if [ -z "$ACR_NAME" ] || [ -z "$RESOURCE_GROUP" ] || [ -z "$JOB_NAME" ]; then
    print_error "Failed to extract configuration from terraform.tfvars"
    exit 1
fi

print_info "Configuration:"
echo "  ACR Name: $ACR_NAME"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Job Name: $JOB_NAME"

# ============================================================================
# STEP 1: Deploy Base Infrastructure
# ============================================================================
echo ""
print_step "STEP 1: Deploying Base Infrastructure"
echo ""

cd "$REPO_ROOT/terraform"

print_info "Initializing Terraform..."
if ! terraform init; then
    print_error "Terraform initialization failed"
    exit 1
fi
print_success "Terraform initialized"

print_info "Validating Terraform configuration..."
if ! terraform validate; then
    print_error "Terraform validation failed"
    exit 1
fi
print_success "Terraform configuration is valid"

print_info "Planning infrastructure deployment (without runner job)..."
PLAN_ARGS=("-var" "github_pat=$GITHUB_PAT" "-var" "deploy_runner_job=false")

if [ "$AUTO_APPROVE" = true ]; then
    PLAN_ARGS+=("-out=tfplan")
fi

if ! terraform plan "${PLAN_ARGS[@]}"; then
    print_error "Terraform plan failed"
    exit 1
fi

if [ "$AUTO_APPROVE" = false ]; then
    echo ""
    read -p "Do you want to deploy the base infrastructure? (yes/no): " APPROVAL
    if [ "$APPROVAL" != "yes" ]; then
        print_warning "Deployment cancelled"
        exit 0
    fi
    
    print_info "Running Terraform plan again to save plan file..."
    if ! terraform plan "${PLAN_ARGS[@]}" -out=tfplan; then
        print_error "Terraform plan failed"
        exit 1
    fi
fi

print_info "Applying Terraform plan..."
if ! terraform apply tfplan; then
    print_error "Terraform apply failed"
    rm -f tfplan
    exit 1
fi
rm -f tfplan

print_success "Base infrastructure deployed successfully!"

# ============================================================================
# STEP 2: Build and Push Docker Image
# ============================================================================
echo ""
print_step "STEP 2: Building and Pushing Docker Image"
echo ""

if [ "$SKIP_IMAGE_BUILD" = true ]; then
    print_warning "Skipping image build as requested"
else
    print_info "Building GitHub runner image..."
    
    if ! "$REPO_ROOT/scripts/run-acr-build.sh" --acr-name "$ACR_NAME"; then
        print_error "Image build failed"
        exit 1
    fi
    
    print_success "Image built and pushed successfully!"
fi

# ============================================================================
# STEP 3: Deploy Container Apps Job
# ============================================================================
echo ""
print_step "STEP 3: Deploying Container Apps Job"
echo ""

print_info "Planning Container Apps Job deployment..."
PLAN_ARGS=("-var" "github_pat=$GITHUB_PAT" "-var" "deploy_runner_job=true")

if [ "$AUTO_APPROVE" = true ]; then
    PLAN_ARGS+=("-out=tfplan")
fi

if ! terraform plan "${PLAN_ARGS[@]}"; then
    print_error "Terraform plan failed"
    exit 1
fi

if [ "$AUTO_APPROVE" = false ]; then
    echo ""
    read -p "Do you want to deploy the Container Apps Job? (yes/no): " APPROVAL
    if [ "$APPROVAL" != "yes" ]; then
        print_warning "Deployment cancelled"
        exit 0
    fi
    
    print_info "Running Terraform plan again to save plan file..."
    if ! terraform plan "${PLAN_ARGS[@]}" -out=tfplan; then
        print_error "Terraform plan failed"
        exit 1
    fi
fi

print_info "Applying Terraform plan..."
if ! terraform apply tfplan; then
    print_error "Terraform apply failed"
    rm -f tfplan
    exit 1
fi
rm -f tfplan

print_success "Container Apps Job deployed successfully!"

# ============================================================================
# STEP 4: Trigger Job (Optional)
# ============================================================================
if [ "$TRIGGER_JOB" = true ]; then
    echo ""
    print_step "STEP 4: Triggering Container Apps Job"
    echo ""
    
    print_info "Starting Container Apps Job..."
    if az containerapp job start --name "$JOB_NAME" --resource-group "$RESOURCE_GROUP"; then
        print_success "Job triggered successfully!"
        echo ""
        print_info "To check job execution status, run:"
        echo "  az containerapp job execution list --name $JOB_NAME --resource-group $RESOURCE_GROUP --output table"
    else
        print_warning "Failed to trigger job (you can trigger it manually later)"
    fi
fi

# ============================================================================
# Deployment Complete
# ============================================================================
echo ""
print_step "Deployment Complete!"
echo ""

print_success "All steps completed successfully!"
echo ""
print_info "Summary:"
echo "  ✓ Base infrastructure deployed"
echo "  ✓ Docker image built and pushed to ACR"
echo "  ✓ Container Apps Job deployed"
if [ "$TRIGGER_JOB" = true ]; then
    echo "  ✓ Job triggered"
fi

echo ""
print_info "Next steps:"
if [ "$TRIGGER_JOB" = false ]; then
    echo "  1. Trigger the job: az containerapp job start --name $JOB_NAME --resource-group $RESOURCE_GROUP"
    echo "  2. Check job execution status: az containerapp job execution list --name $JOB_NAME --resource-group $RESOURCE_GROUP --output table"
    echo "  3. Verify runner in GitHub: Settings → Actions → Runners"
else
    echo "  1. Check job execution status: az containerapp job execution list --name $JOB_NAME --resource-group $RESOURCE_GROUP --output table"
    echo "  2. Verify runner in GitHub: Settings → Actions → Runners"
fi

echo ""
print_info "To trigger the job manually in the future:"
echo "  az containerapp job start --name $JOB_NAME --resource-group $RESOURCE_GROUP"
echo ""
