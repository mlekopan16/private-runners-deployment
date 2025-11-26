<#
.SYNOPSIS
    Terraform Apply Wrapper Script

.DESCRIPTION
    This script helps you deploy infrastructure with Terraform while securely handling secrets.

.PARAMETER PromptSecrets
    Prompt for sensitive values (GitHub PAT)

.PARAMETER GitHubPat
    Provide GitHub PAT directly (not recommended)

.PARAMETER AutoApprove
    Skip Terraform plan approval

.EXAMPLE
    .\terraform-apply.ps1 -PromptSecrets
#>

param(
    [Parameter(Mandatory=$false)]
    [switch]$PromptSecrets,

    [Parameter(Mandatory=$false)]
    [string]$GitHubPat,

    [Parameter(Mandatory=$false)]
    [switch]$AutoApprove
)

$ErrorActionPreference = "Stop"

# Colors for output
function Write-Success { param([string]$Message) Write-Host "✓ $Message" -ForegroundColor Green }
function Write-Error { param([string]$Message) Write-Host "✗ $Message" -ForegroundColor Red }
function Write-Warning { param([string]$Message) Write-Host "⚠ $Message" -ForegroundColor Yellow }
function Write-Info { param([string]$Message) Write-Host "ℹ $Message" -ForegroundColor Blue }

# Determine script directory and repository root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$TerraformDir = Join-Path $RepoRoot "terraform"

if (-not (Test-Path $TerraformDir)) {
    Write-Error "Terraform directory not found"
    exit 1
}

Set-Location $TerraformDir

# Check prerequisites
if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    Write-Error "Terraform is not installed"
    exit 1
}

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Error "Azure CLI is not installed"
    exit 1
}

# Check Azure login
$azAccount = az account show 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Not logged in to Azure"
    Write-Host "Please run: az login"
    exit 1
}

# Get Azure subscription info
Write-Info "Detecting Azure subscription..."
$SubscriptionId = (az account show --query id -o tsv).Trim()
$SubscriptionName = (az account show --query name -o tsv).Trim()

Write-Success "Using Azure subscription: $SubscriptionName ($SubscriptionId)"

# Export subscription ID for Terraform
$env:ARM_SUBSCRIPTION_ID = $SubscriptionId

# Check terraform.tfvars
if (-not (Test-Path "terraform.tfvars")) {
    Write-Warning "terraform.tfvars not found"
    
    if (Test-Path "terraform.tfvars.example") {
        Write-Info "Creating terraform.tfvars from terraform.tfvars.example..."
        Copy-Item "terraform.tfvars.example" "terraform.tfvars"
        Write-Success "Created terraform.tfvars"
        Write-Warning "Please edit terraform.tfvars with your configuration before continuing"
        
        Read-Host "Press Enter to continue after editing terraform.tfvars..."
    } else {
        Write-Error "terraform.tfvars.example not found"
        exit 1
    }
}

# Prompt for GitHub PAT if requested
if ($PromptSecrets -and [string]::IsNullOrWhiteSpace($GitHubPat)) {
    Write-Host ""
    Write-Info "GitHub Personal Access Token (PAT) is required for runner registration"
    Write-Info "The PAT needs the following scopes:"
    Write-Host "  - For repository runners: 'repo' scope"
    Write-Host "  - For organization runners: 'admin:org' scope"
    Write-Host ""
    
    $GitHubPatSecure = Read-Host "Enter GitHub PAT" -AsSecureString
    $GitHubPat = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($GitHubPatSecure))
    
    if ([string]::IsNullOrWhiteSpace($GitHubPat)) {
        Write-Error "GitHub PAT is required"
        exit 1
    }
    
    Write-Success "GitHub PAT received"
}

# Initialize Terraform
Write-Host ""
Write-Info "Initializing Terraform..."
terraform init
if ($LASTEXITCODE -ne 0) { Write-Error "Terraform initialization failed"; exit 1 }
Write-Success "Terraform initialized successfully"

# Validate Terraform configuration
Write-Host ""
Write-Info "Validating Terraform configuration..."
terraform validate
if ($LASTEXITCODE -ne 0) { Write-Error "Terraform validation failed"; exit 1 }
Write-Success "Terraform configuration is valid"

# Run Terraform plan
Write-Host ""
Write-Info "Running Terraform plan..."

$PlanArgs = @()
if (-not [string]::IsNullOrWhiteSpace($GitHubPat)) {
    $PlanArgs += "-var"
    $PlanArgs += "github_pat=$GitHubPat"
}

terraform plan @PlanArgs -out=tfplan
if ($LASTEXITCODE -ne 0) { Write-Error "Terraform plan failed"; exit 1 }
Write-Success "Terraform plan completed successfully"

# Ask for approval
if (-not $AutoApprove) {
    Write-Host ""
    $Approval = Read-Host "Do you want to apply this plan? (yes/no)"
    
    if ($Approval -ne "yes") {
        Write-Warning "Terraform apply cancelled"
        Remove-Item tfplan -ErrorAction SilentlyContinue
        exit 0
    }
}

# Apply Terraform plan
Write-Host ""
Write-Info "Applying Terraform plan..."

terraform apply tfplan
if ($LASTEXITCODE -ne 0) { 
    Write-Error "Terraform apply failed"
    Remove-Item tfplan -ErrorAction SilentlyContinue
    exit 1 
}
Remove-Item tfplan -ErrorAction SilentlyContinue

Write-Success "Terraform apply completed successfully!"

# Show outputs
Write-Host ""
Write-Info "Terraform outputs:"
terraform output

Write-Host ""
Write-Success "Infrastructure deployment complete!"
Write-Host ""
Write-Info "Next steps:"
Write-Host "  1. Build the runner image: ..\scripts\run-acr-build.ps1 -AcrName <your-acr-name>"
Write-Host "  2. Trigger the Container Apps Job to start a runner"
Write-Host "  3. Verify the runner appears in GitHub Settings -> Actions -> Runners"