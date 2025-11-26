# GitHub Runner on Azure Container Apps

Automated deployment of self-hosted GitHub Actions runners using Azure Container Apps Jobs.


## ✨ Features

- ✅ **Fully Automated** - One script deploys everything
- ✅ **Cloud-Based Builds** - No local Docker required (uses Azure Container Registry)
- ✅ **Infrastructure as Code** - Complete Terraform configuration
- ✅ **Secure** - Uses managed identities for ACR authentication
- ✅ **Monitored** - Integrated with Azure Log Analytics
- ✅ **Cost-Effective** - Pay only when runners are active

## 📋 Prerequisites

- Azure CLI ([Install](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli))
- Terraform >= 1.5.0 ([Install](https://developer.hashicorp.com/terraform/install))
- Active Azure subscription
- GitHub Personal Access Token with `repo` or `admin:org` scope

> [!IMPORTANT]
> **GitHub PAT Requirement**: Use  **Classic** Personal Access Token with `repo` scope.
>
> **Note**: Fine-grained tokens *can* be used, but Classic tokens are recommended for simplicity and broader compatibility with self-hosted runner registration.
>
> **How to create a Classic PAT:**
> 1. Go to GitHub Settings -> Developer settings -> Personal access tokens -> Tokens (classic).
> 2. Click "Generate new token" -> "Generate new token (classic)".
> 3. Give it a name, select `repo` scope (or `admin:org` for org runners).
> 4. Generate and copy the token.

## 🎯 What Gets Deployed

The automated deployment creates:

1. **Azure Container Registry** - Stores the GitHub runner Docker image
2. **Container Apps Environment** - Hosts the runner jobs
3. **Log Analytics Workspace** - Collects logs and metrics
4. **Container Apps Job** - Runs the GitHub runner on-demand
5. **Managed Identity** - Secure authentication to ACR

## 📖 Documentation

- **[Configuration Guide](docs/CONFIGURATION.md)** - Detailed configuration options
- **[GitHub Setup Guide](docs/GITHUB_SETUP.md)** - Setting up GitHub PATs and Runners
- **[CI/CD Examples](docs/CI_CD_EXAMPLE.md)** - Example GitHub Actions workflows
- **[Architecture Overview](docs/README.md)** - How it works
- **[Troubleshooting](docs/GITHUB_SETUP.md#troubleshooting)** - Common issues and solutions


## 🔧 Usage

### Automated Deployment (Recommended)

**Linux / macOS:**
```bash
# One-command deployment (Secure)
export GITHUB_PAT_ENV=YOUR_PAT
./scripts/deploy-all.sh --trigger-job

# With auto-approval (no prompts)
export GITHUB_PAT_ENV=YOUR_PAT
./scripts/deploy-all.sh --auto-approve --trigger-job
```

**Windows (PowerShell):**
```powershell
# One-command deployment (Secure)
$env:GITHUB_PAT_ENV="YOUR_PAT"
.\scripts\deploy-all.ps1 -TriggerJob

# With auto-approval (no prompts)
$env:GITHUB_PAT_ENV="YOUR_PAT"
.\scripts\deploy-all.ps1 -AutoApprove -TriggerJob
```



### Manual Deployment

If you prefer step-by-step control:

```bash
# 1. Deploy infrastructure
./scripts/terraform-apply.sh --prompt-secrets

# 2. Build Docker image
./scripts/run-acr-build.sh --acr-name <your-acr-name>

# 3. Deploy Container Apps Job
cd terraform
terraform apply -var="deploy_runner_job=true" -var="github_pat=YOUR_PAT"

# 4. Trigger the job
az containerapp job start --name <job-name> --resource-group <rg-name>
```

## 🎮 Triggering Runners

### Manual Trigger

```bash
az containerapp job start \
  --name job-github-runner \
  --resource-group rg-github-runner-aca
```

### Automated Trigger (GitHub Actions)

You can trigger runners automatically from your GitHub workflows:

```yaml
- name: Trigger Self-Hosted Runner
  run: |
    az login --service-principal -u ${{ secrets.AZURE_CLIENT_ID }} \
      -p ${{ secrets.AZURE_CLIENT_SECRET }} \
      --tenant ${{ secrets.AZURE_TENANT_ID }}
    az containerapp job start \
      --name job-github-runner \
      --resource-group rg-github-runner-aca
```

## 🧪 Example Workflow

You can find a comprehensive example workflow in the `examples` folder: [examples/test-on-self-hosted.yml](examples/test-on-self-hosted.yml).

To test your runner:

1. Copy `examples/test-on-self-hosted.yml` to `.github/workflows/test-runner.yml` in your repository.
2. Push the changes to GitHub.
3. The workflow will trigger automatically (or you can trigger it manually from the Actions tab).

## 📊 Monitoring

### View Job Executions

```bash
az containerapp job execution list \
  --name job-github-runner \
  --resource-group rg-github-runner-aca \
  --output table
```

### View Logs

```bash
az containerapp job execution logs show \
  --name job-github-runner \
  --resource-group rg-github-runner-aca \
  --execution-name <execution-name>
```

### Azure Portal

Navigate to: Azure Portal → Container Apps → job-github-runner → Execution history → Console / System logs

## 🔒 Security

- **Managed Identity** - No credentials stored in code
- **Secrets Management** - GitHub PAT stored as Container Apps secret
- **Private Networking** - Optional VNet integration
- **Image Scanning** - ACR vulnerability scanning available

## 💰 Cost Optimization

Container Apps Jobs only charge when running:
- **Idle Cost**: $0 (no resources allocated when not running)
- **Active Cost**: Only when job is executing
- **Typical Usage**: ~$0.01-0.05 per runner execution

## 🧹 Cleanup

To remove all deployed resources:

```bash
cd terraform
terraform destroy
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## 📝 License

This project is provided as-is for educational and production use.

## 🆘 Support

- Review [Architecture Overview](docs/README.md) for detailed documentation
- Open an issue for bugs or feature requests

## 🎓 Learn More

- [Azure Container Apps Documentation](https://docs.microsoft.com/en-us/azure/container-apps/)
- [GitHub Actions Self-Hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
