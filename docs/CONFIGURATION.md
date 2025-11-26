# Configuration Guide

This guide provides detailed information about all configuration options available in the GitHub Runner ACA solution.

## Table of Contents

- [Azure Configuration](#azure-configuration)
- [Resource Naming](#resource-naming)
- [GitHub Configuration](#github-configuration)
- [Container Image Configuration](#container-image-configuration)
- [Container App Job Configuration](#container-app-job-configuration)
- [Monitoring Configuration](#monitoring-configuration)
- [Tags and Metadata](#tags-and-metadata)
- [Security Configuration](#security-configuration)
- [Environment Variables](#environment-variables)

## Azure Configuration

### location

**Description**: Azure region where resources will be deployed
**Type**: string
**Default**: "East US"
**Example**: `location = "West Europe"`

**Notes**: Choose a region that is:
- Close to your GitHub organization's primary users
- Supports Azure Container Apps
- Has good network connectivity to GitHub

### resource_group_name

**Description**: Name of the Azure resource group
**Type**: string
**Required**: Yes
**Example**: `resource_group_name = "rg-github-runner-prod"`

**Naming Guidelines**:
- Use prefix `rg-` to identify as resource group
- Include environment (prod, dev, test)
- Keep under 90 characters
- Use only alphanumeric characters, hyphens, and underscores

## Resource Naming

### acr_name

**Description**: Name of the Azure Container Registry
**Type**: string
**Required**: Yes
**Constraints**:
- 5-50 alphanumeric characters
- Globally unique within Azure
- No special characters

**Example**: `acr_name = "acrgithubrunnerprod"`

### container_app_environment_name

**Description**: Name of the Container Apps environment
**Type**: string
**Required**: Yes
**Constraints**:
- 2-54 characters
- Alphanumeric characters and hyphens
- Must start with letter and end with alphanumeric

**Example**: `container_app_environment_name = "env-github-runner-prod"`

### github_runner_job_name

**Description**: Name of the GitHub runner Container Apps job
**Type**: string
**Required**: Yes
**Example**: `github_runner_job_name = "job-github-runner-prod"`

## GitHub Configuration

### github_organization

**Description**: GitHub organization name
**Type**: string
**Required**: Yes
**Example**: `github_organization = "my-company"`

**Notes**: This is the GitHub organization where the runner will be registered.

### github_repository

**Description**: GitHub repository name for repository-scoped runners
**Type**: string
**Required**: No
**Default**: "" (empty string for organization-level runners)
**Example**:
```hcl
# Organization-level runner (default)
github_repository = ""

# Repository-level runner
github_repository = "my-specific-repo"
```

### github_runner_labels

**Description**: Labels for the GitHub runner
**Type**: list(string)
**Default**: ["aca-self-hosted"]
**Example**:
```hcl
github_runner_labels = ["aca-self-hosted", "linux", "x64", "large"]
```

**Common Labels**:
- `aca-self-hosted` - Identifies as Container Apps runner
- `linux`, `windows` - Operating system
- `x64`, `arm64` - Architecture
- `large`, `medium`, `small` - Size classification
- Custom labels for your specific needs

### github_runner_group

**Description**: Runner group for the GitHub runner
**Type**: string
**Default**: "default"
**Example**: `github_runner_group = "build-runners"`

**Notes**: Runner groups allow you to organize runners and control which repositories can use them. See the [Authentication and Security](#authentication-and-security) section for GitHub PAT configuration.


## Container Image Configuration

### runner_image_name

**Description**: Name of the runner container image
**Type**: string
**Default**: "github-runner"
**Example**: `runner_image_name = "custom-github-runner"`

### runner_image_tag

**Description**: Tag of the runner container image
**Type**: string
**Default**: "latest"
**Example**:
```hcl
runner_image_tag = "v1.0.0"
runner_image_tag = "2.317.0-ubuntu"
```

**Version Strategy**:
- Use semantic versioning for production releases
- Include GitHub Actions runner version for compatibility tracking
- Use `latest` for development/testing only

## ACR Task Configuration

### acr_task_name

**Description**: Name of the ACR Task for building the runner image
**Type**: string
**Default**: "build-github-runner"
**Example**: `acr_task_name = "task-build-runner"`

### dockerfile_path

**Description**: Path to the Dockerfile relative to repository root
**Type**: string
**Default**: "docker/Dockerfile"
**Example**: `dockerfile_path = "src/docker/Dockerfile"`

### context_path

**Description**: Path to the build context relative to repository root
**Type**: string
**Default**: "docker"
**Example**: `context_path = "src/docker"`

### enable_git_trigger

**Description**: Enable automatic trigger on Git commits
**Type**: bool
**Default**: false
**Example**: `enable_git_trigger = true`

### git_repo_url

**Description**: Git repository URL for ACR Task source (optional)
**Type**: string
**Default**: ""
**Example**: `git_repo_url = "https://github.com/my-org/my-repo.git"`

### git_branch

**Description**: Git branch to build from
**Type**: string
**Default**: "main"
**Example**: `git_branch = "develop"`

### acr_task_cpu

**Description**: CPU cores for ACR Task build
**Type**: number
**Default**: 2
**Example**: `acr_task_cpu = 4`

### acr_build_timeout

**Description**: ACR Task build timeout in seconds
**Type**: number
**Default**: 3600
**Example**: `acr_build_timeout = 7200`

## Container App Job Configuration

### container_app_job_cpu

**Description**: CPU allocation for the container app job
**Type**: string
**Default**: "1.0"
**Valid Values**: "0.25", "0.5", "0.75", "1.0", "1.25", "1.5", "1.75", "2.0", "2.5", "3.0"
**Example**:
```hcl
# Light workloads
container_app_job_cpu = "0.5"

# Heavy workloads
container_app_job_cpu = "2.0"
```

**CPU Guidelines**:
- **0.5**: Light workloads, simple scripts
- **1.0**: Moderate workloads, typical CI/CD
- **2.0+**: Heavy builds, compilation, testing

### container_app_job_memory

**Description**: Memory allocation for the container app job
**Type**: string
**Default**: "2Gi"
**Valid Values**: "0.5Gi", "1Gi", "1.5Gi", "2Gi", "2.5Gi", "3Gi", "3.5Gi", "4Gi"
**Example**:
```hcl
# Light workloads
container_app_job_memory = "1Gi"

# Memory-intensive workloads
container_app_job_memory = "4Gi"
```

**Memory Guidelines**:
- **1Gi**: Simple scripts, small repositories
- **2Gi**: Standard builds, moderate dependencies
- **4Gi+**: Large codebases, parallel testing

### job_execution_timeout

**Description**: Job execution timeout in seconds
**Type**: number
**Default**: 3600 (1 hour)
**Example**:
```hcl
# Short jobs
job_execution_timeout = 1800  # 30 minutes

# Long builds
job_execution_timeout = 7200  # 2 hours
```

**Timeout Guidelines**:
- Set based on your typical job duration
- Consider GitHub Actions job timeout limits (default 6 hours)
- Include buffer for job startup/shutdown time

## Monitoring Configuration

### enable_monitoring

**Description**: Enable Azure Monitor for the Container Apps environment
**Type**: bool
**Default**: true
**Example**: `enable_monitoring = true`

**Benefits**:
- Container console logs visible in Azure Portal
- Log aggregation in Log Analytics
- Performance metrics collection
- Query logs using KQL (Kusto Query Language)
- Alerting capabilities

**Important**: When enabled, the Log Analytics workspace is **directly attached** to the Container Apps Environment, ensuring all container logs are automatically captured and visible.

### log_analytics_workspace_id

**Description**: ID of the Log Analytics workspace for monitoring
**Type**: string
**Required**: No (auto-created if empty when monitoring is enabled)
**Default**: "" (empty - will create new workspace)
**Example**: `log_analytics_workspace_id = "/subscriptions/.../resourceGroups/.../providers/Microsoft.OperationalInsights/workspaces/my-workspace"`

**Behavior**:
- If empty and `enable_monitoring = true`: A new Log Analytics workspace is created automatically
- If provided: Uses the existing workspace (must be in the same subscription and region)
- If `enable_monitoring = false`: No workspace is used

**Use Cases**:
- **New deployment**: Leave empty to auto-create
- **Existing workspace**: Provide workspace ID to consolidate logs
- **Cost optimization**: Share workspace across multiple Container Apps environments

### log_analytics_workspace_name

**Description**: Name of the Log Analytics workspace to create (only used when auto-creating)
**Type**: string
**Default**: "law-github-runner-aca"
**Example**: `log_analytics_workspace_name = "law-github-runner-prod"`

**Notes**: Only used when `enable_monitoring = true` and `log_analytics_workspace_id` is empty.

## Authentication and Security

### Managed Identity Authentication

This solution uses **Azure Managed Identity** for all Azure resource authentication:

**Container Apps Job → ACR**:
- User-assigned managed identity created automatically
- AcrPull role assigned to the identity
- No admin passwords or access keys required
- Container Apps automatically authenticates using the identity

**Benefits**:
- No credentials stored in configuration or state
- Automatic credential rotation by Azure
- Audit trail of all access via Azure Activity Log
- Follows Azure security best practices

**Configuration**:
```hcl
# No additional configuration needed - managed identity is created automatically
# The following happens automatically:
# 1. User-assigned managed identity is created
# 2. Identity is assigned to Container Apps Job
# 3. AcrPull role is granted to the identity on the ACR
# 4. Container Apps uses identity to pull images
```

### GitHub PAT (Personal Access Token)

**Description**: GitHub Personal Access Token for runner registration
**Type**: string
**Required**: Yes
**Sensitive**: Yes
**Example**: Provided via environment variable or interactive prompt

**Required Scopes**:
- For organization runners: `admin:org`, `repo`
- For repository runners: `repo`

**Security Notes**:
- Never commit PAT values to version control
- Use fine-grained tokens with minimal required permissions
- Consider using GitHub Apps for production scenarios
- PAT is only used for runner registration, not stored in ACR or images


## Tags and Metadata

### tags

**Description**: Tags to apply to all Azure resources
**Type**: map(string)
**Default**:
```hcl
tags = {
  "Project"     = "GitHub-Runner-ACA"
  "Environment" = "Production"
  "ManagedBy"   = "Terraform"
}
```

**Recommended Tags**:
```hcl
tags = {
  "Project"     = "GitHub-Runner-ACA"
  "Environment" = var.environment
  "ManagedBy"   = "Terraform"
  "Owner"       = "devops-team@company.com"
  "CostCenter"  = "engineering"
  "TTL"         = "24h"
}
```

## Security Configuration

### Container Security

The solution implements several security measures by default:

1. **Non-root User**: Container runs as non-root user (UID 1001)
2. **Minimal Base Image**: Ubuntu minimal image with required packages only
3. **Managed Identity**: Uses Azure managed identity for resource access
4. **No Secrets in Image**: All secrets passed via environment variables

### Network Security

- **VNet Integration**: Optional (requires custom configuration)
- **Private Endpoints**: Optional for ACR access
- **Network Policies**: Configured via Container Apps environment

### Access Control

- **Role-Based Access**: Minimal Azure RBAC assignments
- **Least Privilege**: Runner only has necessary GitHub permissions
- **Temporary Access**: Runner credentials expire after job completion

## Environment Variables

### Container Environment Variables

The runner container is configured with these environment variables:

```hcl
# GitHub Configuration
GITHUB_OWNER = var.github_organization
GITHUB_REPOSITORY = var.github_repository
GITHUB_TOKEN = var.github_pat

# Runner Configuration
RUNNER_NAME = "aca-runner-${random_id.runner_suffix.hex}"
RUNNER_LABELS = join(",", var.github_runner_labels)
RUNNER_GROUP = var.github_runner_group
```

### Optional Environment Variables

You can customize the runner behavior by setting additional environment variables:

```hcl
# GitHub Enterprise (if applicable)
GITHUB_URL = "https://github.enterprise.com"

# Runner customizations
RUNNER_WORKDIR = "/tmp/runner-work"
RUNNER_USER_AGENT = "my-custom-runner/1.0"
```

## Common Configuration Scenarios

### Development Environment

```hcl
# Development configuration
location = "East US"
resource_group_name = "rg-github-runner-dev"

acr_name = "acrgithubrunnerdev"
container_app_environment_name = "env-github-runner-dev"
github_runner_job_name = "job-github-runner-dev"

github_organization = "my-company"
github_repository = "test-repo"
github_runner_labels = ["aca-self-hosted", "dev", "linux"]

container_app_job_cpu = "0.5"
container_app_job_memory = "1Gi"
job_execution_timeout = 1800

tags = {
  "Project" = "GitHub-Runner-ACA"
  "Environment" = "Development"
  "ManagedBy" = "Terraform"
}
```

### Production Environment

```hcl
# Production configuration
location = "Central US"
resource_group_name = "rg-github-runner-prod"

acr_name = "acrgithubrunnerprod"
container_app_environment_name = "env-github-runner-prod"
github_runner_job_name = "job-github-runner-prod"

github_organization = "my-company"
github_repository = ""  # Organization-level
github_runner_labels = ["aca-self-hosted", "prod", "linux", "x64", "large"]

container_app_job_cpu = "2.0"
container_app_job_memory = "4Gi"
job_execution_timeout = 7200

enable_monitoring = true
log_analytics_workspace_id = "/subscriptions/.../workspaces/production"

tags = {
  "Project" = "GitHub-Runner-ACA"
  "Environment" = "Production"
  "ManagedBy" = "Terraform"
  "Owner" = "platform-team@company.com"
  "CostCenter" = "platform"
}
```

### Multi-Runner Setup

```hcl
# Different runner configurations for different workloads

# Small runners for quick tasks
module "small_runner" {
  source = "./modules/github_runner_job"

  job_name = "job-github-runner-small"
  container_app_job_cpu = "0.5"
  container_app_job_memory = "1Gi"
  github_runner_labels = ["aca-self-hosted", "small", "linux"]
}

# Large runners for heavy builds
module "large_runner" {
  source = "./modules/github_runner_job"

  job_name = "job-github-runner-large"
  container_app_job_cpu = "4.0"
  container_app_job_memory = "8Gi"
  github_runner_labels = ["aca-self-hosted", "large", "linux"]
}
```

## Best Practices

1. **Use Variable Files**: Keep secrets out of version control
2. **Environment Separation**: Use separate configurations for dev/staging/prod
3. **Resource Naming**: Use consistent naming conventions
4. **Tagging**: Implement comprehensive tagging strategy
5. **Monitoring**: Enable monitoring for production deployments
6. **Security**: Regularly rotate GitHub tokens
7. **Cost Management**: Right-size resources based on actual usage
8. **Backup**: Keep Terraform state backed up and secure