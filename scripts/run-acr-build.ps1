<#
.SYNOPSIS
    Builds the GitHub Runner Docker image using Azure Container Registry

.DESCRIPTION
    This script builds the Docker image using ACR. It supports both:
    1. Local builds using 'az acr build' (default)
    2. Remote builds using 'az acr task run' (if configured)

.PARAMETER AcrName
    Name of the Azure Container Registry

.EXAMPLE
    .\run-acr-build.ps1 -AcrName "myacr"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$AcrName
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

# Check prerequisites
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

# Get configuration from terraform.tfvars
$TfVarsPath = "$RepoRoot/terraform/terraform.tfvars"
if (-not (Test-Path $TfVarsPath)) {
    Write-Error "terraform.tfvars not found"
    exit 1
}

$TfVarsContent = Get-Content $TfVarsPath -Raw
if ($TfVarsContent -match 'image_name\s*=\s*"([^"]+)"') { $ImageName = $matches[1] }
if ($TfVarsContent -match 'default_image_tag\s*=\s*"([^"]+)"') { $ImageTag = $matches[1] }
if ($TfVarsContent -match 'dockerfile_path\s*=\s*"([^"]+)"') { $DockerfilePath = $matches[1] }
if ($TfVarsContent -match 'context_path\s*=\s*"([^"]+)"') { $ContextPath = $matches[1] }
if ($TfVarsContent -match 'acr_task_name\s*=\s*"([^"]+)"') { $TaskName = $matches[1] }
if ($TfVarsContent -match 'enable_git_trigger\s*=\s*true') { $EnableGitTrigger = $true } else { $EnableGitTrigger = $false }

# Set defaults if not found
if ([string]::IsNullOrWhiteSpace($ImageName)) { $ImageName = "github-runner" }
if ([string]::IsNullOrWhiteSpace($ImageTag)) { $ImageTag = "latest" }
if ([string]::IsNullOrWhiteSpace($DockerfilePath)) { $DockerfilePath = "docker/Dockerfile" }
if ([string]::IsNullOrWhiteSpace($ContextPath)) { $ContextPath = "docker" }
if ([string]::IsNullOrWhiteSpace($TaskName)) { $TaskName = "build-github-runner" }

Write-Info "Configuration:"
Write-Host "  ACR Name: $AcrName"
Write-Host "  Image: ${ImageName}:${ImageTag}"
Write-Host "  Context: $ContextPath"
Write-Host "  Dockerfile: $DockerfilePath"

# Get ACR Login Server
Write-Info "Retrieving ACR login server..."
$LoginServer = (az acr show --name $AcrName --query loginServer --output tsv).Trim()
if ([string]::IsNullOrWhiteSpace($LoginServer)) {
    Write-Error "Failed to retrieve ACR login server"
    exit 1
}
Write-Info "ACR Login Server: $LoginServer"

# Build Image
if ($EnableGitTrigger) {
    Write-Info "Git trigger is enabled. Using ACR Task: $TaskName"
    
    # Check if task exists
    az acr task show --name $TaskName --registry $AcrName --output none 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "ACR Task '$TaskName' not found. Please deploy infrastructure first."
        exit 1
    }
    
    Write-Info "Triggering ACR Task run..."
    az acr task run --name $TaskName --registry $AcrName
    if ($LASTEXITCODE -ne 0) {
        Write-Error "ACR Task run failed"
        exit 1
    }
} else {
    Write-Info "Using local build context: $ContextPath"
    
    $ContextFullPath = Join-Path $RepoRoot $ContextPath
    $DockerfileFullPath = Join-Path $RepoRoot $DockerfilePath
    
    if (-not (Test-Path $ContextFullPath)) {
        Write-Error "Context directory not found: $ContextFullPath"
        exit 1
    }
    
    if (-not (Test-Path $DockerfileFullPath)) {
        Write-Error "Dockerfile not found: $DockerfileFullPath"
        exit 1
    }
    
    Write-Info "Starting build (this may take a few minutes)..."
    az acr build --registry $AcrName --image "$ImageName`:$ImageTag" --file $DockerfileFullPath $ContextFullPath
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "ACR build failed"
        exit 1
    }
}

Write-Success "ACR build completed successfully!"
Write-Info "Built image: $LoginServer/$ImageName`:$ImageTag"

# Verify image
Write-Info "Verifying image in ACR..."
$Tags = az acr repository show-tags --name $AcrName --repository $ImageName --output tsv 2>$null
if ($Tags -contains $ImageTag) {
    Write-Success "Image successfully pushed to ACR"
    
    Write-Info "Image details:"
    az acr manifest list-metadata --registry $AcrName --name $ImageName --query "[?tags[0]=='$ImageTag']" --output table
} else {
    Write-Error "Image tag '$ImageTag' not found in repository '$ImageName'"
    exit 1
}

# Save image reference
$ImageRef = "$LoginServer/$ImageName`:$ImageTag"
$ImageRef | Out-File -FilePath "$RepoRoot/.image-reference" -Encoding UTF8
Write-Info "Image reference saved to .image-reference file"