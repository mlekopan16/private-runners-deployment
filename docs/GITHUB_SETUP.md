# GitHub Setup Guide

This guide covers the GitHub-specific setup required for the Azure Container Apps GitHub Runner solution.

## Table of Contents

- [Prerequisites](#prerequisites)
- [GitHub Personal Access Token](#github-personal-access-token)
- [GitHub App Alternative](#github-app-alternative)
- [Runner Registration](#runner-registration)
- [Repository and Organization Setup](#repository-and-organization-setup)
- [Testing the Runner](#testing-the-runner)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Permissions

- **Organization Owner** or **Repository Admin** permissions
- Ability to create personal access tokens or GitHub Apps
- Access to organization/repository settings

### GitHub Account Types

- **Free Plan**: Limited to 2000 minutes per month for private repositories
- **Team Plan**: 3000 minutes per month for private repositories
- **Enterprise Plan**: Unlimited minutes for private repositories

## GitHub Personal Access Token (PAT)

### Creating a Personal Access Token

1. **Navigate to GitHub Settings**
   - Click your profile picture → **Settings**
   - Scroll down to **Developer settings** (left sidebar)
   - Click **Personal access tokens** → **Tokens (classic)**

2. **Generate New Token**
   - Click **Generate new token (classic)**
   - Give it a descriptive name (e.g., "Azure Container Apps Runner")

3. **Configure Token**
   - **Expiration**: Choose 90 days or custom (GitHub requires expiration)
   - **Scopes**: Select appropriate scopes based on runner type

### PAT Scopes

#### For Organization-Level Runners

```
admin:org         # Manage organization runners
repo              # Access repositories (required for workflow execution)
read:org          # Read organization information
```

#### For Repository-Level Runners

```
repo              # Access repositories
```

#### Recommended Scopes

**Minimal setup**:
```
repo              # Required for workflow execution
admin:org         # Only for organization runners
```

**Enhanced setup** (for monitoring and management):
```
repo              # Required for workflow execution
admin:org         # Only for organization runners
read:org          # For organization information
read:repo         # For repository metadata
```

### PAT Security Best Practices

1. **Use Expiration**: Set reasonable expiration (90 days maximum)
2. **Minimal Scopes**: Only grant required permissions
3. **Regular Rotation**: Establish a rotation schedule
4. **Secure Storage**: Never commit PAT values to version control
5. **Audit Usage**: Monitor PAT usage in GitHub audit logs

### Using the PAT

The PAT can be provided in several ways:

#### Method 1: Environment Variable with Deploy Script (Recommended)

```bash
# Linux/macOS
export GITHUB_PAT_ENV="your_pat_here"
./scripts/deploy-all.sh --trigger-job

# Windows (PowerShell)
$env:GITHUB_PAT_ENV="your_pat_here"
.\scripts\deploy-all.ps1 -TriggerJob
```

#### Method 2: Interactive Prompt

```bash
# Linux/macOS
./scripts/deploy-all.sh --trigger-job
# You will be prompted to enter the PAT

# Windows (PowerShell)
.\scripts\deploy-all.ps1 -TriggerJob
```

#### Method 3: Terraform Variable File (Not Recommended)

```hcl
# terraform.tfvars (ensure this file is in .gitignore)
github_pat = "your_pat_here"
```

⚠️ **Warning**: Method 3 is not recommended for production as it stores secrets in plain text.

## GitHub App Alternative

For production environments, GitHub Apps provide better security and management capabilities compared to PATs.

### When to Use GitHub Apps

- Production deployments
- Organization-wide runner management
- Enhanced security requirements
- Multiple repositories/organizations
- Automated token rotation

### Creating a GitHub App

1. **Navigate to GitHub App Settings**
   - Organization Settings → **Developer settings** → **GitHub Apps**
   - Click **New GitHub App**

2. **Configure App**
   - **App name**: "Azure Container Apps Runner"
   - **Homepage URL**: Your organization's website
   - **Webhook URL**: Optional (not required for runners)
   - **Permissions**:
     - **Administration**: Read & write (for runner management)
     - **Metadata**: Read-only
     - **Actions**: Read & write (for workflow execution)

3. **Repository Access**
   - Choose "All repositories" or specific repositories
   - This determines where the runner can be used

4. **Generate Private Key**
   - Download the private key (.pem file)
   - Store securely for Terraform configuration

### GitHub App Configuration in Terraform

```hcl
# Terraform variables for GitHub App
variable "github_app_id" {
  description = "GitHub App ID"
  type        = string
}

variable "github_app_private_key" {
  description = "GitHub App private key"
  type        = string
  sensitive   = true
}
```

## Runner Registration

### Organization-Level Runners

1. **Navigate to Organization Settings**
   - Organization → **Settings** → **Actions** → **Runners**

2. **Check Runner Groups**
   - Verify runner groups exist or create new ones
   - Default runners go to "Default" group

3. **Permissions**
   - Ensure runner groups allow your target repositories

### Repository-Level Runners

1. **Navigate to Repository Settings**
   - Repository → **Settings** → **Actions** → **Runners**

2. **Security Settings**
   - Review "Fork pull request workflows from outside collaborators" setting
   - Consider your security requirements for fork PRs

## Repository and Organization Setup

### Workflow Permissions

Configure appropriate workflow permissions for your use case:

#### Organization Level

1. **Organization Settings** → **Actions** → **General**
2. **Workflow permissions**:
   - **Read repository contents and packages** (recommended for most cases)
   - **Read and write permissions** (if workflows need to push to repository)

#### Repository Level

1. **Repository Settings** → **Actions** → **General**
2. **Workflow permissions**: Same options as organization level

### Runner Group Configuration

#### Creating Custom Runner Groups

1. **Organization Settings** → **Actions** → **Runner groups**
2. **New runner group**:
   - Name (e.g., "build-runners", "deploy-runners")
   - Visibility: Public or Restricted
   - Repository access: All or specific repositories

#### Runner Group Benefits

- **Security**: Control which repositories can use specific runners
- **Cost Management**: Separate runner types for different workloads
- **Organization**: Logical grouping of runners by purpose

### Self-Hosted Runner Policies

Configure policies for self-hosted runners:

1. **Organization Settings** → **Actions** → **General**
2. **Self-hosted runner policies**:
   - Allow or restrict public repositories
   - Configure fork pull request policies
   - Set workflow permission defaults

## Testing the Runner

### 1. Verify Runner Registration

After Terraform deployment:

1. Navigate to **Settings → Actions → Runners**
2. Look for your runner with labels like "aca-self-hosted"
3. Status should show as "Idle" when not running jobs

### 2. Create Test Workflow

You can use the comprehensive example provided in the repository:

1. Copy `examples/test-on-self-hosted.yml` to `.github/workflows/test-runner.yml` in your repository.
2. Commit and push the file to GitHub.

Alternatively, create a simple test file `.github/workflows/test-simple.yml`:

```yaml
name: Simple Test
on: [workflow_dispatch]
jobs:
  test:
    runs-on: aca-self-hosted
    steps:
      - run: echo "Hello from Azure Container Apps!"
```

### 3. Trigger Test Workflow

#### Manual Trigger

1. Go to **Actions** tab in your repository
2. Select the "Test Self-Hosted Runner" workflow
3. Click **Run workflow** → **Run workflow**

#### Automatic Trigger

Push a change to the main branch to automatically trigger the workflow.

### 4. Monitor Runner Activity

1. **GitHub**:
   - **Settings → Actions → Runners** - See runner status
   - **Actions → [workflow name]** - View job logs

2. **Azure**:
   ```bash
   # Check Container App Job executions
   az containerapp job execution list \
     --name your-job-name \
     --resource-group your-resource-group \
     --output table
   ```

## Troubleshooting

### Common Issues

#### Runner Not Appearing in GitHub

**Symptoms**: Runner shows as deployed in Azure but not visible in GitHub runner list.

**Causes & Solutions**:
1. **Invalid GitHub Token**
   ```bash
   # Test your PAT
   curl -H "Authorization: token YOUR_PAT" https://api.github.com/user
   ```

2. **Insufficient Permissions**
   - Verify PAT has required scopes
   - Check organization permissions

3. **Network Connectivity**
   - Verify container can reach GitHub API
   - Check firewall/proxy settings

4. **Runner Registration Timeout**
   - Check Container App Job logs
   - Verify job execution timeout settings

#### Runner Registration Fails

**Symptoms**: Runner appears briefly then disappears from GitHub.

**Solutions**:
1. **Check Container App Job Logs**:
   ```bash
   az containerapp job execution show \
     --name your-job-name \
     --resource-group your-resource-group \
     --job-execution-name <execution-id>
   ```

2. **Verify Environment Variables**:
   - Ensure GITHUB_PAT is correctly set
   - Check GITHUB_OWNER value
   - Verify GITHUB_REPOSITORY if using repo-scoped runner

3. **Check Runner Startup Script**:
   - Review start-runner.sh logs
   - Verify runner configuration values

#### Jobs Fail to Start

**Symptoms**: Runner is visible but jobs don't start or fail immediately.

**Solutions**:
1. **Check Runner Configuration**:
   - Verify runner labels match workflow `runs-on:` values
   - Ensure runner is not in a restricted group

2. **Verify Repository Permissions**:
   - Check if repository can access the runner group
   - Verify workflow permissions

3. **Check Resource Allocation**:
   - Verify CPU/memory allocation is sufficient
   - Check job timeout settings

#### Token Expiration Issues

**Symptoms**: Runner works initially then fails after some time.

**Solutions**:
1. **Check Token Expiration**:
   - PAT tokens expire after configured time
   - Consider using GitHub Apps for long-running deployments

2. **Implement Token Rotation**:
   - Set up automated token renewal
   - Use GitHub Apps for production deployments

### Debug Commands

#### Azure Commands

```bash
# List Container App Jobs
az containerapp job list \
  --resource-group your-resource-group \
  --output table

# Get job details
az containerapp job show \
  --name your-job-name \
  --resource-group your-resource-group

# List job executions
az containerapp job execution list \
  --name your-job-name \
  --resource-group your-resource-group \
  --output table

# Get specific execution logs
az containerapp logs show \
  --name your-job-name \
  --resource-group your-resource-group \
  --job-execution-name <execution-id>
```

#### GitHub API Commands

```bash
# Test GitHub API access
curl -H "Authorization: token YOUR_PAT" https://api.github.com/user

# List organization runners
curl -H "Authorization: token YOUR_PAT" https://api.github.com/orgs/YOUR_ORG/actions/runners

# List repository runners
curl -H "Authorization: token YOUR_PAT" https://api.github.com/repos/YOUR_ORG/YOUR_REPO/actions/runners
```

## Security Best Practices

### Token Security

1. **Use Short-Lived Tokens**: Set reasonable expiration dates
2. **Minimal Scopes**: Only grant required permissions
3. **Regular Rotation**: Establish token rotation schedule
4. **Monitor Usage**: Check GitHub audit logs regularly

### Runner Security

1. **Network Isolation**: Consider VNet integration if available
2. **Secrets Management**: Use GitHub secrets, not environment variables
3. **Container Security**: Regularly update base images
4. **Access Control**: Use runner groups to restrict repository access

### Monitoring and Auditing

1. **GitHub Audit Logs**: Monitor token usage and runner registration
2. **Azure Monitoring**: Enable Container Apps monitoring
3. **Workflow Security**: Review workflow permissions regularly
4. **Compliance**: Ensure setup meets organizational security requirements