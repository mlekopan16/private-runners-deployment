<#
.SYNOPSIS
    Complete Deployment Script for GitHub Runner on Azure Container Apps

.DESCRIPTION
    This script automates the entire deployment process:
    1. Deploy base infrastructure (ACR, Container Apps Environment, etc.)
    2. Build and push the GitHub runner Docker image
    3. Deploy the Container Apps Job
    4. Optionally trigger the job

.PARAMETER GitHubPat
    GitHub Personal Access Token for runner registration

.PARAMETER TriggerJob
    Trigger the Container Apps Job after deployment

.PARAMETER AutoApprove
    Skip Terraform approval prompts

.PARAMETER SkipImageBuild
    Skip Docker image build (use if image already exists)

.EXAMPLE
    .\deploy-all.ps1 -GitHubPat "ghp_xxxxxxxxxxxx" -TriggerJob
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$GitHubPat,

    [Parameter(Mandatory=$false)]
    [switch]$TriggerJob,

    [Parameter(Mandatory=$false)]
    [switch]$AutoApprove,

    [Parameter(Mandatory=$false)]
    [switch]$SkipImageBuild
)

$ErrorActionPreference = "Stop"

# Colors for output
function Write-Success { param([string]$Message) Write-Host "✓ $Message" -ForegroundColor Green }
function Write-Error { param([string]$Message) Write-Host "✗ $Message" -ForegroundColor Red }
function Write-Warning { param([string]$Message) Write-Host "⚠ $Message" -ForegroundColor Yellow }
function Write-Info { param([string]$Message) Write-Host "ℹ $Message" -ForegroundColor Blue }
function Write-Step { 
    param([string]$Message) 
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "  $Message" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
}

# Validate GitHub PAT
if ([string]::IsNullOrWhiteSpace($GitHubPat)) {
    # Check environment variables
    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_PAT_ENV)) {
        $GitHubPat = $env:GITHUB_PAT_ENV
    } elseif (-not [string]::IsNullOrWhiteSpace($env:TF_VAR_github_pat)) {
        $GitHubPat = $env:TF_VAR_github_pat
    } else {
        Write-Error "GitHub PAT is required"
        Write-Host "You can provide it in one of three ways:"
        Write-Host "  1. Command line: .\deploy-all.ps1 -GitHubPat <token>"
        Write-Host "  2. Environment variable: `$env:GITHUB_PAT_ENV='<token>'"
        Write-Host "  3. Terraform variable: `$env:TF_VAR_github_pat='<token>'"
        exit 1
    }
}

# Determine script directory and repository root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir

Write-Host ""
Write-Step "GitHub Runner on Azure Container Apps - Complete Deployment"
Write-Host ""
Write-Info "This script will:"
Write-Host "  1. Deploy base infrastructure (ACR, Container Apps Environment, Log Analytics)"
Write-Host "  2. Build and push GitHub runner Docker image to ACR"
Write-Host "  3. Deploy Container Apps Job with the runner"
if ($TriggerJob) {
    Write-Host "  4. Trigger the Container Apps Job to start a runner"
}
Write-Host ""

# Check prerequisites
Write-Info "Checking prerequisites..."

if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    Write-Error "Terraform is not installed"
    Write-Host "Please install Terraform from: https://www.terraform.io/downloads.html"
    exit 1
}

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Error "Azure CLI is not installed"
    Write-Host "Please install Azure CLI from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
}

# Check Azure login
$azAccount = az account show 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Not logged in to Azure"
    Write-Host "Please run: az login"
    exit 1
}

Write-Success "All prerequisites met"

# Get Azure subscription info
$SubscriptionId = (az account show --query id -o tsv).Trim()
$SubscriptionName = (az account show --query name -o tsv).Trim()
$env:ARM_SUBSCRIPTION_ID = $SubscriptionId

Write-Host ""
Write-Info "Using Azure subscription: $SubscriptionName ($SubscriptionId)"

# Check if terraform.tfvars exists
if (-not (Test-Path "$RepoRoot/terraform/terraform.tfvars")) {
    Write-Error "terraform.tfvars not found"
    Write-Host "Please create terraform/terraform.tfvars from terraform/terraform.tfvars.example"
    exit 1
}

# Extract configuration from terraform.tfvars
$TfVarsContent = Get-Content "$RepoRoot/terraform/terraform.tfvars" -Raw
if ($TfVarsContent -match 'acr_name\s*=\s*"([^"]+)"') { $AcrName = $matches[1] }
if ($TfVarsContent -match 'resource_group_name\s*=\s*"([^"]+)"') { $ResourceGroup = $matches[1] }
if ($TfVarsContent -match 'github_runner_job_name\s*=\s*"([^"]+)"') { $JobName = $matches[1] }

if ([string]::IsNullOrWhiteSpace($AcrName) -or [string]::IsNullOrWhiteSpace($ResourceGroup) -or [string]::IsNullOrWhiteSpace($JobName)) {
    Write-Error "Failed to extract configuration from terraform.tfvars"
    exit 1
}

Write-Info "Configuration:"
Write-Host "  ACR Name: $AcrName"
Write-Host "  Resource Group: $ResourceGroup"
Write-Host "  Job Name: $JobName"

# ============================================================================
# STEP 1: Deploy Base Infrastructure
# ============================================================================
Write-Host ""
Write-Step "STEP 1: Deploying Base Infrastructure"
Write-Host ""

Set-Location "$RepoRoot/terraform"

Write-Info "Initializing Terraform..."
terraform init
if ($LASTEXITCODE -ne 0) { Write-Error "Terraform initialization failed"; exit 1 }
Write-Success "Terraform initialized"

Write-Info "Validating Terraform configuration..."
terraform validate
if ($LASTEXITCODE -ne 0) { Write-Error "Terraform validation failed"; exit 1 }
Write-Success "Terraform configuration is valid"

Write-Info "Planning infrastructure deployment (without runner job)..."
$PlanArgs = @("-var", "github_pat=$GitHubPat", "-var", "deploy_runner_job=false")

if ($AutoApprove) {
    $PlanArgs += "-out=tfplan"
}

terraform plan @PlanArgs
if ($LASTEXITCODE -ne 0) { Write-Error "Terraform plan failed"; exit 1 }

if (-not $AutoApprove) {
    Write-Host ""
    $Approval = Read-Host "Do you want to deploy the base infrastructure? (yes/no)"
    if ($Approval -ne "yes") {
        Write-Warning "Deployment cancelled"
        exit 0
    }
    
    Write-Info "Running Terraform plan again to save plan file..."
    terraform plan @PlanArgs -out=tfplan
    if ($LASTEXITCODE -ne 0) { Write-Error "Terraform plan failed"; exit 1 }
}

Write-Info "Applying Terraform plan..."
terraform apply tfplan
if ($LASTEXITCODE -ne 0) { 
    Write-Error "Terraform apply failed"
    Remove-Item tfplan -ErrorAction SilentlyContinue
    exit 1 
}
Remove-Item tfplan -ErrorAction SilentlyContinue

Write-Success "Base infrastructure deployed successfully!"

# ============================================================================
# STEP 2: Build and Push Docker Image
# ============================================================================
Write-Host ""
Write-Step "STEP 2: Building and Pushing Docker Image"
Write-Host ""

if ($SkipImageBuild) {
    Write-Warning "Skipping image build as requested"
} else {
    Write-Info "Building GitHub runner image..."
    
    # Call the PowerShell version of the build script
    & "$RepoRoot/scripts/run-acr-build.ps1" -AcrName $AcrName
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Image build failed"
        exit 1
    }
    
    Write-Success "Image built and pushed successfully!"
}

# ============================================================================
# STEP 3: Deploy Container Apps Job
# ============================================================================
Write-Host ""
Write-Step "STEP 3: Deploying Container Apps Job"
Write-Host ""

Write-Info "Planning Container Apps Job deployment..."
$PlanArgs = @("-var", "github_pat=$GitHubPat", "-var", "deploy_runner_job=true")

if ($AutoApprove) {
    $PlanArgs += "-out=tfplan"
}

terraform plan @PlanArgs
if ($LASTEXITCODE -ne 0) { Write-Error "Terraform plan failed"; exit 1 }

if (-not $AutoApprove) {
    Write-Host ""
    $Approval = Read-Host "Do you want to deploy the Container Apps Job? (yes/no)"
    if ($Approval -ne "yes") {
        Write-Warning "Deployment cancelled"
        exit 0
    }
    
    Write-Info "Running Terraform plan again to save plan file..."
    terraform plan @PlanArgs -out=tfplan
    if ($LASTEXITCODE -ne 0) { Write-Error "Terraform plan failed"; exit 1 }
}

Write-Info "Applying Terraform plan..."
terraform apply tfplan
if ($LASTEXITCODE -ne 0) { 
    Write-Error "Terraform apply failed"
    Remove-Item tfplan -ErrorAction SilentlyContinue
    exit 1 
}
Remove-Item tfplan -ErrorAction SilentlyContinue

Write-Success "Container Apps Job deployed successfully!"

# ============================================================================
# STEP 4: Trigger Job (Optional)
# ============================================================================
if ($TriggerJob) {
    Write-Host ""
    Write-Step "STEP 4: Triggering Container Apps Job"
    Write-Host ""
    
    Write-Info "Starting Container Apps Job..."
    az containerapp job start --name $JobName --resource-group $ResourceGroup
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Job triggered successfully!"
        Write-Host ""
        Write-Info "To check job execution status, run:"
        Write-Host "  az containerapp job execution list --name $JobName --resource-group $ResourceGroup --output table"
    } else {
        Write-Warning "Failed to trigger job (you can trigger it manually later)"
    }
}

# ============================================================================
# Deployment Complete
# ============================================================================
Write-Host ""
Write-Step "Deployment Complete!"
Write-Host ""

Write-Success "All steps completed successfully!"
Write-Host ""
Write-Info "Summary:"
Write-Host "  ✓ Base infrastructure deployed"
Write-Host "  ✓ Docker image built and pushed to ACR"
Write-Host "  ✓ Container Apps Job deployed"
if ($TriggerJob) {
    Write-Host "  ✓ Job triggered"
}

Write-Host ""
Write-Info "Next steps:"
if (-not $TriggerJob) {
    Write-Host "  1. Trigger the job: az containerapp job start --name $JobName --resource-group $ResourceGroup"
    Write-Host "  2. Check job execution status: az containerapp job execution list --name $JobName --resource-group $ResourceGroup --output table"
    Write-Host "  3. Verify runner in GitHub: Settings -> Actions -> Runners"
} else {
    Write-Host "  1. Check job execution status: az containerapp job execution list --name $JobName --resource-group $ResourceGroup --output table"
    Write-Host "  2. Verify runner in GitHub: Settings -> Actions -> Runners"
}

Write-Host ""
Write-Info "To trigger the job manually in the future:"
Write-Host "  az containerapp job start --name $JobName --resource-group $ResourceGroup"
Write-Host ""
