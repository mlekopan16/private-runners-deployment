#!/bin/bash

# Exit on any error
set -e

# Function to cleanup runner
cleanup_runner() {
    echo "Cleaning up runner..."
    if [ -n "$RUNNER_NAME" ] && [ -n "$GITHUB_TOKEN" ]; then
        echo "Deregistering runner: $RUNNER_NAME"
        ./config.sh remove --token "$GITHUB_TOKEN" --unattended || echo "Failed to deregister runner"
    fi
    exit 0
}

# Set up signal handlers for graceful shutdown
trap cleanup_runner SIGINT SIGTERM

# Check required environment variables
if [ -z "$GITHUB_OWNER" ]; then
    echo "Error: GITHUB_OWNER environment variable is required"
    exit 1
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: GITHUB_TOKEN environment variable is required"
    exit 1
fi

# Set default values for optional variables
GITHUB_URL="${GITHUB_URL:-https://github.com}"
RUNNER_NAME="${RUNNER_NAME:-$(hostname)}"
RUNNER_LABELS="${RUNNER_LABELS:-self-hosted,linux}"
RUNNER_GROUP="${RUNNER_GROUP:-default}"

# Determine if this is a repository or organization runner
if [ -n "$GITHUB_REPOSITORY" ] && [ "$GITHUB_REPOSITORY" != "" ]; then
    # Repository-level runner
    REPO_URL="${GITHUB_URL}/${GITHUB_OWNER}/${GITHUB_REPOSITORY}"
    echo "Setting up repository-level runner for: ${GITHUB_OWNER}/${GITHUB_REPOSITORY}"
    SCOPE_ARG="--url ${REPO_URL}"
else
    # Organization-level runner
    ORG_URL="${GITHUB_URL}/${GITHUB_OWNER}"
    echo "Setting up organization-level runner for: ${GITHUB_OWNER}"
    SCOPE_ARG="--url ${ORG_URL}"
fi

echo "Runner configuration:"
echo "  Name: $RUNNER_NAME"
echo "  Labels: $RUNNER_LABELS"
echo "  Group: $RUNNER_GROUP"
echo "  Scope: $([ -n "$GITHUB_REPOSITORY" ] && echo "Repository" || echo "Organization")"

# Generate a registration token from the PAT
echo "Generating registration token..."

# Determine API path based on scope
if [ -n "$GITHUB_REPOSITORY" ] && [ "$GITHUB_REPOSITORY" != "" ]; then
    API_PATH="repos/${GITHUB_OWNER}/${GITHUB_REPOSITORY}"
else
    API_PATH="orgs/${GITHUB_OWNER}"
fi

# Construct API URL (handle github.com vs GitHub Enterprise)
if [ "$GITHUB_URL" = "https://github.com" ]; then
    API_URL="https://api.github.com/${API_PATH}/actions/runners/registration-token"
else
    # GitHub Enterprise
    API_URL="${GITHUB_URL}/api/v3/${API_PATH}/actions/runners/registration-token"
fi

echo "API URL: $API_URL"

# Make API call and capture full response for debugging
API_RESPONSE=$(curl -s -X POST \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    "$API_URL")

echo "API Response: $API_RESPONSE"

REGISTRATION_TOKEN=$(echo "$API_RESPONSE" | jq -r '.token')

if [ -z "$REGISTRATION_TOKEN" ] || [ "$REGISTRATION_TOKEN" = "null" ]; then
    echo "Error: Failed to generate registration token"
    echo "API Response: $API_RESPONSE"
    echo ""
    echo "Please check your GitHub token has the correct permissions:"
    echo "  - For repo runners: 'repo' scope"
    echo "  - For org runners: 'admin:org' scope"
    echo ""
    echo "Common issues:"
    echo "  1. Token has expired"
    echo "  2. Token doesn't have required scopes"
    echo "  3. Repository/Organization name is incorrect"
    echo "  4. Token is for a different GitHub account"
    exit 4
fi

echo "Registration token generated successfully"

# Configure the runner
echo "Configuring runner..."
./config.sh \
    --unattended \
    --name "${RUNNER_NAME}" \
    --labels "${RUNNER_LABELS}" \
    --runnergroup "${RUNNER_GROUP}" \
    $SCOPE_ARG \
    --token "${REGISTRATION_TOKEN}"

echo "Runner configured successfully"

# Start the runner
echo "Starting runner..."
./run.sh