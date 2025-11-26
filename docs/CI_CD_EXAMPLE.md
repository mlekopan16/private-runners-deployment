# CI/CD Examples and Workflows

This guide provides practical examples of using the Azure Container Apps GitHub Runner in various CI/CD scenarios.

## Table of Contents

- [Basic Workflows](#basic-workflows)
- [Build and Test Workflows](#build-and-test-workflows)
- [Container-Based Workflows](#container-based-workflows)
- [Multi-Language Examples](#multi-language-examples)
- [Deployment Workflows](#deployment-workflows)
- [Matrix Builds](#matrix-builds)
- [Advanced Patterns](#advanced-patterns)
- [Performance Optimization](#performance-optimization)
- [Troubleshooting Common Issues](#troubleshooting-common-issues)

## Basic Workflows

### Simple Test Workflow

Create `.github/workflows/simple-test.yml`:

```yaml
name: Simple Test

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: aca-self-hosted

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Runner Information
        run: |
          echo "Runner OS: $(uname -a)"
          echo "Runner User: $(whoami)"
          echo "Working Directory: $(pwd)"

      - name: Basic Tests
        run: |
          echo "Running basic tests..."
          # Add your test commands here
```

### Multi-Step Workflow

Create `.github/workflows/multi-step.yml`:

```yaml
name: Multi-Step Pipeline

on:
  workflow_dispatch:
  push:
    branches: [ main ]

jobs:
  setup:
    runs-on: aca-self-hosted
    outputs:
      build-number: ${{ steps.build-number.outputs.number }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Generate Build Number
        id: build-number
        run: |
          BUILD_NUMBER=$(date +%Y%m%d-%H%M%S)
          echo "number=$BUILD_NUMBER" >> $GITHUB_OUTPUT
          echo "Build Number: $BUILD_NUMBER"

  build:
    needs: setup
    runs-on: aca-self-hosted

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Display Build Info
        run: |
          echo "Build Number: ${{ needs.setup.outputs.build-number }}"
          echo "Commit: ${{ github.sha }}"
          echo "Branch: ${{ github.ref }}"

      - name: Build Application
        run: |
          echo "Building application..."
          # Add your build commands here

  test:
    needs: setup
    runs-on: aca-self-hosted

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Run Tests
        run: |
          echo "Running tests..."
          # Add your test commands here
```

## Build and Test Workflows

### Node.js Application

Create `.github/workflows/nodejs.yml`:

```yaml
name: Node.js CI/CD

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: aca-self-hosted
    strategy:
      matrix:
        node-version: [18.x, 20.x]

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js ${{ matrix.node-version }}
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run linting
        run: npm run lint

      - name: Run type checking
        run: npm run type-check

      - name: Run unit tests
        run: npm run test:unit

      - name: Run integration tests
        run: npm run test:integration

      - name: Generate coverage report
        run: npm run coverage

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          file: ./coverage/lcov.info
```

### Python Application

Create `.github/workflows/python.yml`:

```yaml
name: Python CI/CD

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: aca-self-hosted
    strategy:
      matrix:
        python-version: ['3.9', '3.10', '3.11']

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Python ${{ matrix.python-version }}
        uses: actions/setup-python@v4
        with:
          python-version: ${{ matrix.python-version }}

      - name: Cache pip packages
        uses: actions/cache@v3
        with:
          path: ~/.cache/pip
          key: ${{ runner.os }}-pip-${{ hashFiles('**/requirements.txt') }}
          restore-keys: |
            ${{ runner.os }}-pip-

      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements.txt
          pip install -r requirements-dev.txt

      - name: Run linting
        run: |
          flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics
          flake8 . --count --exit-zero --max-complexity=10 --max-line-length=127 --statistics

      - name: Run type checking
        run: mypy .

      - name: Run tests
        run: |
          pytest --cov=. --cov-report=xml

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          file: ./coverage.xml
```

### Java/Maven Application

Create `.github/workflows/maven.yml`:

```yaml
name: Java CI with Maven

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: aca-self-hosted
    strategy:
      matrix:
        java-version: [11, 17, 21]

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up JDK ${{ matrix.java-version }}
        uses: actions/setup-java@v4
        with:
          java-version: ${{ matrix.java-version }}
          distribution: 'temurin'

      - name: Cache Maven packages
        uses: actions/cache@v3
        with:
          path: ~/.m2
          key: ${{ runner.os }}-m2-${{ hashFiles('**/pom.xml') }}
          restore-keys: |
            ${{ runner.os }}-m2-

      - name: Run tests
        run: mvn clean test

      - name: Run integration tests
        run: mvn clean verify -P integration-tests

      - name: Generate test report
        uses: dorny/test-reporter@v1
        if: success() || failure()
        with:
          name: Maven Tests
          path: target/surefire-reports/*.xml
          reporter: java-junit
```

## Multi-Language Examples

### Full-Stack Application

Create `.github/workflows/full-stack.yml`:

```yaml
name: Full-Stack CI/CD

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  backend-tests:
    runs-on: aca-self-hosted
    defaults:
      run:
        working-directory: ./backend

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: backend/package-lock.json

      - name: Install dependencies
        run: npm ci

      - name: Run linting
        run: npm run lint

      - name: Run tests
        run: npm run test:coverage

  frontend-tests:
    runs-on: aca-self-hosted
    defaults:
      run:
        working-directory: ./frontend

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: frontend/package-lock.json

      - name: Install dependencies
        run: npm ci

      - name: Run linting
        run: npm run lint

      - name: Run tests
        run: npm run test:coverage

      - name: Build application
        run: npm run build

  e2e-tests:
    needs: [backend-tests, frontend-tests]
    runs-on: aca-self-hosted

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Compose
        run: |
          sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
          sudo chmod +x /usr/local/bin/docker-compose

      - name: Start services
        run: |
          docker-compose -f docker-compose.test.yml up -d
          sleep 30

      - name: Run E2E tests
        run: |
          cd e2e-tests
          npm ci
          npm run test

      - name: Cleanup
        if: always()
        run: |
          docker-compose -f docker-compose.test.yml down
```

## Deployment Workflows

### Azure Web App Deployment

Create `.github/workflows/azure-webapp.yml`:

```yaml
name: Deploy to Azure Web App

on:
  push:
    branches: [ main ]
  workflow_dispatch:

env:
  AZURE_WEBAPP_NAME: your-webapp-name
  AZURE_RESOURCE_GROUP: your-resource-group

jobs:
  build:
    runs-on: aca-self-hosted

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm run test

      - name: Build application
        run: npm run build

      - name: Upload build artifacts
        uses: actions/upload-artifact@v3
        with:
          name: build-files
          path: dist/

  deploy:
    needs: build
    runs-on: aca-self-hosted
    environment: production

    steps:
      - name: Download build artifacts
        uses: actions/download-artifact@v3
        with:
          name: build-files
          path: dist/

      - name: Login to Azure
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Deploy to Azure Web App
        uses: azure/webapps-deploy@v2
        with:
          app-name: ${{ env.AZURE_WEBAPP_NAME }}
          resource-group: ${{ env.AZURE_RESOURCE_GROUP }}
          package: dist/
```

### Terraform Deployment

Create `.github/workflows/terraform.yml`:

```yaml
name: Terraform Deploy

on:
  push:
    branches: [ main ]
    paths: [ 'terraform/**' ]
  workflow_dispatch:

jobs:
  terraform:
    runs-on: aca-self-hosted
    environment: production

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.5.0"

      - name: Terraform Init
        run: |
          cd terraform
          terraform init

      - name: Terraform Plan
        run: |
          cd terraform
          terraform plan -out=tfplan

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main'
        run: |
          cd terraform
          terraform apply -auto-approve tfplan
```

## Matrix Builds

### Multi-Platform Matrix

Create `.github/workflows/matrix-build.yml`:

```yaml
name: Matrix Build

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: aca-self-hosted
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, windows-latest]
        node-version: [18.x, 20.x]
        include:
          - os: ubuntu-latest
            os-name: linux
          - os: windows-latest
            os-name: windows

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js ${{ matrix.node-version }}
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm run test

      - name: Upload test results
        uses: actions/upload-artifact@v3
        if: always()
        with:
          name: test-results-${{ matrix.os-name }}-${{ matrix.node-version }}
          path: test-results/
```

## Advanced Patterns

### Conditional Deployments

Create `.github/workflows/conditional-deploy.yml`:

```yaml
name: Conditional Deployment

on:
  push:
    branches: [ main ]

jobs:
  detect-changes:
    runs-on: aca-self-hosted
    outputs:
      backend-changed: ${{ steps.changes.outputs.backend }}
      frontend-changed: ${{ steps.changes.outputs.frontend }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 2

      - name: Detect changes
        id: changes
        run: |
          if git diff --name-only HEAD~1 HEAD | grep -q "^backend/"; then
            echo "backend=true" >> $GITHUB_OUTPUT
          else
            echo "backend=false" >> $GITHUB_OUTPUT
          fi

          if git diff --name-only HEAD~1 HEAD | grep -q "^frontend/"; then
            echo "frontend=true" >> $GITHUB_OUTPUT
          else
            echo "frontend=false" >> $GITHUB_OUTPUT
          fi

  deploy-backend:
    needs: detect-changes
    if: needs.detect-changes.outputs.backend-changed == 'true'
    runs-on: aca-self-hosted

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Deploy Backend
        run: |
          echo "Deploying backend..."
          # Add deployment commands

  deploy-frontend:
    needs: detect-changes
    if: needs.detect-changes.outputs.frontend-changed == 'true'
    runs-on: aca-self-hosted

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Deploy Frontend
        run: |
          echo "Deploying frontend..."
          # Add deployment commands
```

### Parallel Testing

Create `.github/workflows/parallel-tests.yml`:

```yaml
name: Parallel Testing

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  split-tests:
    runs-on: aca-self-hosted
    outputs:
      test-files: ${{ steps.split.outputs.test-files }}
      total-tests: ${{ steps.split.outputs.total-tests }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Split tests
        id: split
        run: |
          # Find all test files and split them into chunks
          TESTS=$(find . -name "*.test.js" -o -name "*.spec.js" | tr '\n' ',')
          TOTAL=$(echo "$TESTS" | tr ',' '\n' | wc -l)
          echo "test-files=$TESTS" >> $GITHUB_OUTPUT
          echo "total-tests=$TOTAL" >> $GITHUB_OUTPUT

  test:
    needs: split-tests
    runs-on: aca-self-hosted
    strategy:
      fail-fast: false
      matrix:
        shard-index: [0, 1, 2, 3]

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run shard tests
        run: |
          IFS=',' read -ra TEST_ARRAY <<< "${{ needs.split-tests.outputs.test-files }}"
          SHARD_SIZE=$((${{ needs.split-tests.outputs.total-tests }} / 4))
          START_INDEX=$((${{ matrix.shard-index }} * SHARD_SIZE))
          END_INDEX=$((((${{ matrix.shard-index }} + 1)) * SHARD_SIZE))

          TEST_SHARD=""
          for ((i=START_INDEX; i<END_INDEX; i++)); do
            if [ -n "${TEST_ARRAY[$i]}" ]; then
              TEST_SHARD="$TEST_SHARD ${TEST_ARRAY[$i]}"
            fi
          done

          echo "Running tests for shard ${{ matrix.shard-index }}: $TEST_SHARD"
          npm test -- $TEST_SHARD
```

## Troubleshooting Common Issues

### Debug Workflow

Create `.github/workflows/debug.yml`:

```yaml
name: Debug Workflow

on:
  workflow_dispatch:
    inputs:
      debug_enabled:
        description: 'Run with tmate debugging enabled'
        required: false
        default: false

jobs:
  debug:
    runs-on: aca-self-hosted

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        run: npm ci

      - name: Setup tmate session
        if: github.event.inputs.debug_enabled == 'true'
        uses: mxschmitt/action-tmate@v3
        timeout-minutes: 30

      - name: Runner Information
        run: |
          echo "Runner information:"
          uname -a
          df -h
          free -h
          docker --version

      - name: Environment Variables
        run: |
          echo "Environment variables:"
          env | sort

      - name: Network Test
        run: |
          echo "Network connectivity:"
          curl -I https://github.com
          curl -I https://api.github.com

      - name: Test Build
        run: |
          npm run build

      - name: Test Run
        run: |
          npm test
```

### Health Check Workflow

Create `.github/workflows/health-check.yml`:

```yaml
name: Health Check

on:
  schedule:
    - cron: '0 0 * * *'  # Daily at midnight
  workflow_dispatch:

jobs:
  health-check:
    runs-on: aca-self-hosted

    steps:
      - name: Check Runner Health
        run: |
          echo "=== Runner Health Check ==="
          echo "Uptime: $(uptime)"
          echo "Memory Usage: $(free -h)"
          echo "Disk Usage: $(df -h)"
          echo "Docker Status: $(systemctl is-active docker || echo 'Docker not running as service')"

      - name: Test GitHub Connectivity
        run: |
          echo "=== GitHub Connectivity ==="
          curl -s -o /dev/null -w "%{http_code}" https://github.com
          curl -s -o /dev/null -w "%{http_code}" https://api.github.com

      - name: Test Container Registry
        run: |
          echo "=== Container Registry Test ==="
          docker pull hello-world
          docker run --rm hello-world

      - name: Cleanup
        run: |
          echo "=== Cleanup ==="
          docker system prune -f
          npm cache clean --force
```

These examples demonstrate various patterns and best practices for using the Azure Container Apps GitHub Runner in different CI/CD scenarios. Customize them according to your specific requirements and project structure.