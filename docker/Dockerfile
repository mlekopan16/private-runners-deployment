# Use Ubuntu as base image
FROM ubuntu:22.04

# Set environment variables to avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    ca-certificates \
    gnupg \
    git \
    unzip \
    jq \
    software-properties-common \
    apt-transport-https \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Install Docker CLI for container-based workflows
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# Optional: Install additional tools commonly used in CI/CD
# Uncomment these lines if you need these tools in your workflows
# RUN apt-get update && apt-get install -y \
#     nodejs \
#     npm \
#     python3 \
#     python3-pip \
#     && rm -rf /var/lib/apt/lists/*

# Optional: Install Azure CLI
# RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Optional: Install Terraform
# RUN wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip \
#     && unzip terraform_1.6.0_linux_amd64.zip \
#     && mv terraform /usr/local/bin/ \
#     && rm terraform_1.6.0_linux_amd64.zip

# Create a non-root user for security
ARG RUNNER_UID=1001
ARG RUNNER_GID=121
RUN groupadd -g ${RUNNER_GID} runner \
    && useradd -u ${RUNNER_UID} -g runner -m runner \
    && echo "runner ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Create runner directory and set ownership
RUN mkdir -p /opt/runner && chown -R runner:runner /opt/runner

# Set working directory
WORKDIR /opt/runner

# Download and install GitHub Actions runner
ARG RUNNER_VERSION="2.330.0"
RUN curl -L -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz \
    && tar xzf ./actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz \
    && rm actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz \
    && ./bin/installdependencies.sh \
    && chown -R runner:runner /opt/runner

# Copy the runner startup script
COPY start-runner.sh /opt/runner/start-runner.sh
RUN chmod +x /opt/runner/start-runner.sh \
    && chown runner:runner /opt/runner/start-runner.sh

# Switch to runner user
USER runner

# Expose port (not strictly necessary for Container Apps Jobs)
EXPOSE 80

# Set the entrypoint to the startup script
ENTRYPOINT ["/opt/runner/start-runner.sh"]