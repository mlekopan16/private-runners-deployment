# Architecture Overview

This document provides a deep dive into the architecture of the Azure Container Apps GitHub Runner solution.

## 🏗️ Architecture Diagram

The solution creates an automated GitHub self-hosted runner deployment using:

- **Azure Container Registry (ACR)** - Stores the custom runner Docker image with cloud-native builds
- **ACR Tasks** - Cloud-based Docker image building and automation
- **Azure Container Apps Environment** - Provides the managed environment for running containerized applications
- **Azure Container Apps Job** - Runs ephemeral GitHub runner instances on-demand
- **Managed Identity** - Secure authentication between Container Apps and ACR
- **Terraform** - Infrastructure as code for automated deployment

![Architecture Diagram](https://mermaid.ink/img/Z3JhcGggVEQKICAgIFVzZXJbVXNlci9DSV0gLS0+fFRyaWdnZXJ8IEpvYltDb250YWluZXIgQXBwIEpvYl0KICAgIEFDUltBenVyZSBDb250YWluZXIgUmVnaXN0cnldIC0tPnxQdWxsIEltYWdlfCBKb2IKICAgIEpvYiAtLT58UmVnaXN0ZXJ8IEdpdEh1YltHaXRIdWJdCiAgICBBQ1JUYXNrW0FDUiBUYXNrXSAtLT58QnVpbGQgJiBQdXNofCBBQ1IKICAgIEpvYiAtLT58TG9nc3wgTG9nW0xvZyBBbmFseXRpY3Nd)

## 🔍 Component Details

### Azure Container Apps Job

The core of the solution is the Container Apps Job. Unlike Container Apps (which are for services), Jobs are designed for ephemeral tasks that start, run, and exit.

- **Event-Driven**: Can be triggered manually, by schedule, or by events (KEDA).
- **Ephemeral**: Each job execution creates a fresh container that is destroyed after completion.
- **Scalable**: Supports parallel executions for concurrent workflow runs.

### Azure Container Registry (ACR)

ACR is used to store the custom runner image.

- **Private Registry**: Secure storage for your runner images.
- **ACR Tasks**: Automates the build process in the cloud, eliminating the need for local Docker.
- **Managed Identity**: Uses Azure Managed Identity for secure pull access from Container Apps.

### Managed Identity

Security is handled via User-Assigned Managed Identities.

- **Identity**: `id-github-runner` (default name)
- **Role**: `AcrPull` on the Container Registry
- **Assignment**: Assigned to the Container App Job
- **Benefit**: No need to manage or rotate service principal secrets.

### Networking

- **Public/Private**: The Container Apps Environment can be deployed with a public endpoint or injected into a VNet (requires custom Terraform configuration).
- **Outbound Access**: Runners need outbound access to `github.com` and `api.github.com`.

## 🔄 Workflow Flow

1. **Deployment**: Terraform provisions ACR, Environment, Job, and Identity.
2. **Build**: `run-acr-build` script triggers ACR Task to build the runner image from `docker/Dockerfile`.
3. **Trigger**:
   - **Manual**: User triggers the job via CLI or Portal.
   - **Automated**: GitHub Workflow uses Azure CLI to trigger the job.
4. **Execution**:
   - Job starts a new pod.
   - Container pulls image from ACR using Managed Identity.
   - Runner starts and registers with GitHub using the PAT.
   - Runner listens for a job (or picks up a queued one).
   - Job executes.
   - Runner deregisters (if configured) or simply exits.
   - Pod is terminated.

## 📊 Monitoring

Logs are streamed to Azure Log Analytics.

- **Console Logs**: Standard output from the runner.
- **System Logs**: Container startup/shutdown events.
- **Metrics**: CPU/Memory usage.