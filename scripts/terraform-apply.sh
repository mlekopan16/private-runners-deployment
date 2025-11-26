#!/bin/bash

# Terraform Apply Wrapper Script
# This script helps you deploy infrastructure with Terraform while securely handling secrets

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

# Parse command line arguments
PROMPT_SECRETS=false
GITHUB_PAT=""
AUTO_APPROVE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --prompt-secrets)
            PROMPT_SECRETS=true
            shift
            ;;
        --github-pat)
            GITHUB_PAT="$2"
            shift 2
            ;;
        --auto-approve)
            AUTO_APPROVE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --prompt-secrets     Prompt for sensitive values (GitHub PAT)"
            echo "  --github-pat TOKEN   Provide GitHub PAT directly (not recommended)"
            echo "  --auto-approve       Skip Terraform plan approval"
            echo "  -h, --help           Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

print_info "Terraform Apply Wrapper Script"
echo ""

# Check if we're in the terraform directory
if [ ! -f "main.tf" ]; then
    if [ -d "terraform" ]; then
        print_info "Changing to terraform directory..."
        cd terraform
    else
        print_error "Not in terraform directory and terraform/ not found"
        echo "Please run this script from the repository root or terraform directory"
        exit 1
    fi
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed"
    echo "Please install Terraform from: https://www.terraform.io/downloads.html"
    exit 1
fi

print_success "Terraform is installed"

# Check if Azure CLI is installed and user is logged in
if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed"
    echo "Please install Azure CLI from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Get the current Azure subscription ID
print_info "Detecting Azure subscription..."
SUBSCRIPTION_ID=$(az account show --query id -o tsv 2>&1)

if [ $? -ne 0 ] || [ -z "$SUBSCRIPTION_ID" ]; then
    print_error "Not logged in to Azure or no subscription selected"
    echo "Please run: az login"
    echo "Then set your subscription: az account set --subscription <subscription-id>"
    exit 1
fi

SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
print_success "Using Azure subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"

# Export subscription ID for Terraform
export ARM_SUBSCRIPTION_ID="$SUBSCRIPTION_ID"

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    print_warning "terraform.tfvars not found"
    
    if [ -f "terraform.tfvars.example" ]; then
        print_info "Creating terraform.tfvars from terraform.tfvars.example..."
        cp terraform.tfvars.example terraform.tfvars
        print_success "Created terraform.tfvars"
        print_warning "Please edit terraform.tfvars with your configuration before continuing"
        
        read -p "Press Enter to continue after editing terraform.tfvars..."
    else
        print_error "terraform.tfvars.example not found"
        exit 1
    fi
fi

# Prompt for GitHub PAT if requested
if [ "$PROMPT_SECRETS" = true ] && [ -z "$GITHUB_PAT" ]; then
    echo ""
    print_info "GitHub Personal Access Token (PAT) is required for runner registration"
    print_info "The PAT needs the following scopes:"
    echo "  - For repository runners: 'repo' scope"
    echo "  - For organization runners: 'admin:org' scope"
    echo ""
    
    read -s -p "Enter GitHub PAT: " GITHUB_PAT
    echo ""
    
    if [ -z "$GITHUB_PAT" ]; then
        print_error "GitHub PAT is required"
        exit 1
    fi
    
    print_success "GitHub PAT received"
fi

# Initialize Terraform
echo ""
print_info "Initializing Terraform..."
if terraform init; then
    print_success "Terraform initialized successfully"
else
    print_error "Terraform initialization failed"
    exit 1
fi

# Validate Terraform configuration
echo ""
print_info "Validating Terraform configuration..."
if terraform validate; then
    print_success "Terraform configuration is valid"
else
    print_error "Terraform validation failed"
    exit 1
fi

# Run Terraform plan
echo ""
print_info "Running Terraform plan..."

PLAN_ARGS=()

if [ -n "$GITHUB_PAT" ]; then
    PLAN_ARGS+=("-var" "github_pat=$GITHUB_PAT")
fi

if terraform plan "${PLAN_ARGS[@]}" -out=tfplan; then
    print_success "Terraform plan completed successfully"
else
    print_error "Terraform plan failed"
    exit 1
fi

# Ask for approval unless auto-approve is set
if [ "$AUTO_APPROVE" = false ]; then
    echo ""
    read -p "Do you want to apply this plan? (yes/no): " APPROVAL
    
    if [ "$APPROVAL" != "yes" ]; then
        print_warning "Terraform apply cancelled"
        rm -f tfplan
        exit 0
    fi
fi

# Apply Terraform plan
echo ""
print_info "Applying Terraform plan..."

if terraform apply tfplan; then
    print_success "Terraform apply completed successfully!"
    rm -f tfplan
else
    print_error "Terraform apply failed"
    rm -f tfplan
    exit 1
fi

# Show outputs
echo ""
print_info "Terraform outputs:"
terraform output -json > ../outputs.json
terraform output

echo ""
print_success "Infrastructure deployment complete!"
echo ""
print_info "Next steps:"
echo "  1. Build the runner image: ../scripts/run-acr-build.sh --acr-name <your-acr-name>"
echo "  2. Trigger the Container Apps Job to start a runner"
echo "  3. Verify the runner appears in GitHub Settings → Actions → Runners"
