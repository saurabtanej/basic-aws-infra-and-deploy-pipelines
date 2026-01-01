# Java REST API - AWS ECS Fargate Infrastructure

[![CI/CD Pipeline](https://github.com/YOUR_USERNAME/basic-aws-infra-and-deploy-pipelines/actions/workflows/deploy.yml/badge.svg)](https://github.com/YOUR_USERNAME/basic-aws-infra-and-deploy-pipelines/actions/workflows/deploy.yml)
[![Terraform](https://github.com/YOUR_USERNAME/basic-aws-infra-and-deploy-pipelines/actions/workflows/terraform.yml/badge.svg)](https://github.com/YOUR_USERNAME/basic-aws-infra-and-deploy-pipelines/actions/workflows/terraform.yml)

Production-ready infrastructure for deploying a Java REST API to AWS ECS Fargate with CI/CD, monitoring, and multi-environment support via Terragrunt.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Terragrunt Usage](#terragrunt-usage)
- [Terraform Usage](#terraform-usage)
- [Docker](#docker)
- [CI/CD Pipeline](#cicd-pipeline)
- [Monitoring](#monitoring)
- [Security](#security)
- [Cost Optimization](#cost-optimization)
- [Troubleshooting](#troubleshooting)
- [Required Secrets](#required-secrets)

## Overview

This project provides:

- **Infrastructure as Code**: Terraform with official AWS modules
- **Environment Management**: Terragrunt for DRY multi-environment configs
- **Containerized Application**: Java Spring Boot with Docker
- **CI/CD Pipeline**: GitHub Actions for automated deployments
- **Monitoring**: New Relic Java Agent APM + CloudWatch

## Design Decisions

### Why Terragrunt?

We use [Terragrunt](https://terragrunt.gruntwork.io/) instead of Terraform workspaces for multi-environment management because:

| Feature | Terraform Workspaces | Terragrunt |
|---------|---------------------|------------|
| **State isolation** | Shared state file | Separate state per environment |
| **DRY configuration** | Limited | Excellent - inherit common configs |
| **Environment-specific values** | Variable files | Hierarchical inputs |
| **Remote state setup** | Manual per workspace | Automatic S3/DynamoDB creation |
| **Dependency management** | Manual | Built-in `dependency` blocks |
| **Blast radius** | Higher (shared state) | Lower (isolated states) |

**Key benefits in this project:**
- `terragrunt/_envcommon/app.hcl` - Shared configuration (health checks, ports)
- `terragrunt/{env}/terragrunt.hcl` - Environment-specific overrides
- Automatic S3 bucket and DynamoDB table creation for state
- Each environment has completely isolated state

### Why Official Terraform Modules?

We use [terraform-aws-modules](https://github.com/terraform-aws-modules) instead of custom modules because:

- **Battle-tested**: Used by thousands of organizations
- **Maintained**: Regular updates and security patches
- **Feature-rich**: Covers edge cases we might miss
- **Documented**: Extensive documentation and examples

| Module | Version | Why |
|--------|---------|-----|
| `vpc/aws` | 5.16.0 | Handles NAT, flow logs, DNS settings |
| `alb/aws` | 9.12.0 | Target groups, listeners, health checks |
| `ecs/aws` | 5.11.4 | Fargate, auto-scaling, task definitions |
| `security-group/aws` | 5.2.0 | Ingress/egress rules with descriptions |

### Why New Relic Java Agent (not sidecar)?

For Java APM, the **in-app agent** is the recommended approach because:

- **Deep code-level instrumentation** - Method-level tracing
- **Transaction tracing** - End-to-end request visibility
- **Error tracking** - Stack traces with context
- **Custom metrics** - Via `@Trace` annotations and API
- **Lower overhead** - Single process vs sidecar container

See [docs/NEWRELIC.md](docs/NEWRELIC.md) for complete setup.

### Why GitHub OIDC (not Access Keys)?

We use OpenID Connect for AWS authentication because:

- **No long-lived credentials** - Tokens expire after each job
- **No secret rotation** - AWS trusts GitHub's identity provider
- **Audit trail** - Clear identity in CloudTrail logs
- **Least privilege** - Scoped to specific repos/branches

See [docs/GITHUB_SECRETS.md](docs/GITHUB_SECRETS.md) for setup.

## Architecture

```
                                    ┌─────────────────────────────────────────────────────────┐
                                    │                        AWS Cloud                        │
                                    │                                                         │
    ┌──────────┐                    │   ┌─────────────────────────────────────────────────┐   │
    │          │                    │   │                      VPC                        │   │
    │  Users   │                    │   │                   10.0.0.0/16                   │   │
    │          │                    │   │                                                 │   │
    └────┬─────┘                    │   │   ┌─────────────────┐  ┌─────────────────┐      │   │
         │                          │   │   │  Public Subnet  │  │  Public Subnet  │      │   │
         │ HTTP/HTTPS               │   │   │   10.0.1.0/24   │  │   10.0.2.0/24   │      │   │
         │                          │   │   │    (AZ-1a)      │  │    (AZ-1b)      │      │   │
         ▼                          │   │   │                 │  │                 │      │   │
    ┌──────────┐                    │   │   │  ┌───────────┐  │  │  ┌───────────┐  │      │   │
    │   ALB    │────────────────────┼───┼──►│  │   Target  │◄─┼──┼──┤   Target  │  │      │   │
    │          │                    │   │   │  │   Group   │  │  │  │   Group   │  │      │   │
    └──────────┘                    │   │   │  └─────┬─────┘  │  │  └─────┬─────┘  │      │   │
                                    │   │   └────────┼────────┘  └────────┼────────┘      │   │
                                    │   │            │                    │               │   │
                                    │   │   ┌────────┼────────┐  ┌────────┼────────┐      │   │
                                    │   │   │ Private Subnet  │  │ Private Subnet  │      │   │
                                    │   │   │   10.0.10.0/24  │  │   10.0.20.0/24  │      │   │
                                    │   │   │                 │  │                 │      │   │
                                    │   │   │  ┌───────────┐  │  │  ┌───────────┐  │      │   │
                                    │   │   │  │   ECS     │  │  │  │   ECS     │  │      │   │
                                    │   │   │  │  Fargate  │  │  │  │  Fargate  │  │      │   │
                                    │   │   │  │   Task    │  │  │  │   Task    │  │      │   │
                                    │   │   │  └───────────┘  │  │  └───────────┘  │      │   │
                                    │   │   │                 │  │                 │      │   │
                                    │   │   │  ┌───────────┐  │  │                 │      │   │
                                    │   │   │  │    NAT    │──┼──┼─► Internet      │      │   │
                                    │   │   │  │  Gateway  │  │  │                 │      │   │
                                    │   │   │  └───────────┘  │  │                 │      │   │
                                    │   │   └─────────────────┘  └─────────────────┘      │   │
                                    │   └─────────────────────────────────────────────────┘   │
                                    │                                                         │
                                    │   ┌──────────┐  ┌──────────┐  ┌──────────────────┐     │
                                    │   │   ECR    │  │CloudWatch│  │ Secrets Manager  │     │
                                    │   │   Repo   │  │   Logs   │  │  (New Relic Key) │     │
                                    │   └──────────┘  └──────────┘  └──────────────────┘     │
                                    └─────────────────────────────────────────────────────────┘
```

### CI/CD Flow

```
┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐
│  Push   │────►│  Build  │────►│  Test   │────►│  Push   │────►│ Deploy  │
│  Code   │     │   App   │     │   App   │     │ to ECR  │     │ to ECS  │
└─────────┘     └─────────┘     └─────────┘     └─────────┘     └─────────┘
```

## Repository Structure

```
.
├── .github/workflows/
│   ├── deploy.yml              # Main CI/CD pipeline
│   └── terraform.yml           # Terraform validation
├── docker/
│   └── Dockerfile              # Multi-stage build with New Relic
├── docs/
│   ├── GITHUB_SECRETS.md       # Secrets documentation
│   └── NEWRELIC.md             # New Relic setup guide
├── src/
│   ├── main/java/              # Java source code
│   ├── main/resources/         # Application config + newrelic.yml
│   ├── test/                   # Unit tests
│   └── pom.xml                 # Maven configuration
├── terraform/                  # Infrastructure code
│   ├── locals.tf               # Local values
│   ├── versions.tf             # Provider versions
│   ├── variables.tf            # Variable definitions
│   ├── outputs.tf              # Output definitions
│   ├── vpc.tf                  # VPC module
│   ├── security-groups.tf      # Security groups
│   ├── ecr.tf                  # ECR repository
│   ├── alb.tf                  # Load balancer
│   ├── ecs.tf                  # ECS cluster & service
│   ├── iam.tf                  # IAM module reference
│   ├── cloudwatch.tf           # Logs & alarms
│   └── modules/iam/            # Custom IAM module
├── terragrunt/                 # Environment management
│   ├── terragrunt.hcl          # Root config
│   ├── _envcommon/app.hcl      # Shared settings
│   ├── dev/                    # Dev environment
│   ├── staging/                # Staging environment
│   └── prod/                   # Production environment
├── .gitignore
└── README.md
```

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Terraform | >= 1.6.0 | Infrastructure as Code |
| Terragrunt | >= 0.54.0 | Environment management |
| AWS CLI | >= 2.0 | AWS interactions |
| Docker | >= 24.0 | Container builds |
| Java | 21 | Application development |
| Maven | >= 3.9 | Java build tool |

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/saurabtanej/basic-aws-infra-and-deploy-pipelines
cd basic-aws-infra-and-deploy-pipelines
```

### 2. Configure AWS Credentials

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="me-south-1"  # Bahrain - closest to Dubai
```

### 3. Deploy with Terragrunt (Recommended)

```bash
cd terragrunt/dev
terragrunt init
terragrunt plan
terragrunt apply
```

### 4. Build and Push Docker Image

```bash
# Get ECR URL from Terraform output
ECR_URL=$(terragrunt output -raw ecr_repository_url)

# Login to ECR
aws ecr get-login-password --region me-south-1 | docker login --username AWS --password-stdin $ECR_URL

# Build and push
docker build -t $ECR_URL:latest -f docker/Dockerfile .
docker push $ECR_URL:latest
```

### 5. Access the Application

```bash
ALB_URL=$(terragrunt output -raw alb_dns_name)
curl http://$ALB_URL/health
```

## Terragrunt Usage

Terragrunt provides DRY configuration for multiple environments.

### Directory Structure

```
terragrunt/
├── terragrunt.hcl          # Root: remote state, provider config
├── _envcommon/
│   └── app.hcl             # Shared inputs (health check, ports)
├── dev/
│   ├── env.hcl             # Environment name & region
│   └── terragrunt.hcl      # Dev-specific settings
├── staging/
│   ├── env.hcl
│   └── terragrunt.hcl
└── prod/
    ├── env.hcl
    └── terragrunt.hcl
```

### Commands

```bash
# Deploy to dev
cd terragrunt/dev
terragrunt apply

# Deploy to staging
cd terragrunt/staging
terragrunt apply

# Deploy to production
cd terragrunt/prod
terragrunt apply

# Deploy all environments
cd terragrunt
terragrunt run-all apply

# Destroy an environment
cd terragrunt/dev
terragrunt destroy
```

### Environment Differences

| Setting | Dev | Staging | Prod |
|---------|-----|---------|------|
| VPC CIDR | 10.0.0.0/16 | 10.1.0.0/16 | 10.2.0.0/16 |
| AZs | 2 | 2 | 3 |
| NAT Gateways | 1 (cost saving) | 1 | 1 per AZ (HA) |
| CPU | 256 | 512 | 1024 |
| Memory | 512 MB | 1024 MB | 2048 MB |
| Min Tasks | 1 | 1 | 2 |
| Max Tasks | 2 | 3 | 10 |
| Log Retention | 7 days | 14 days | 30 days |
| Container Insights | Disabled | Enabled | Enabled |

## Terraform Usage

If you prefer Terraform without Terragrunt:

```bash
cd terraform

# Initialize
terraform init

# Plan with variable file (create your own)
terraform plan -var="environment=dev" -var="project_name=java-api"

# Apply
terraform apply -var="environment=dev" -var="project_name=java-api"
```

### Official Modules Used

| Module | Version | Purpose |
|--------|---------|---------|
| terraform-aws-modules/vpc/aws | 5.16.0 | VPC, subnets, NAT |
| terraform-aws-modules/alb/aws | 9.12.0 | Application Load Balancer |
| terraform-aws-modules/ecs/aws | 5.11.4 | ECS Cluster & Service |
| terraform-aws-modules/security-group/aws | 5.2.0 | Security Groups |

## Docker

### Dockerfile Features

- **Multi-stage build**: Small final image (~300MB)
- **Amazon Corretto 21**: AWS-optimized JDK
- **Non-root user**: Security best practice
- **Health check**: Built-in container health monitoring
- **New Relic Java Agent**: APM integration
- **dumb-init**: Proper signal handling

### Build Locally

```bash
docker build -t java-api -f docker/Dockerfile .
docker run -p 8080:8080 -e ENVIRONMENT=local java-api
```

### Endpoints

| Endpoint | Purpose |
|----------|---------|
| `GET /health` | Health check (used by ALB) |
| `GET /` | Welcome message |
| `GET /info` | Application info |
| `GET /actuator/health` | Detailed health (Spring Actuator) |

## CI/CD Pipeline

### Triggers

| Event | Action |
|-------|--------|
| Push to `main` | Build → Test → Push to ECR → Deploy to dev |
| Pull Request | Build → Test only |
| Manual dispatch | Deploy to selected environment |

### Pipeline Stages

1. **Build & Test**: Compile Java, run unit tests
2. **Build & Push**: Build Docker image, push to ECR with SHA tag
3. **Deploy Dev**: Update ECS service, verify health
4. **Deploy Staging/Prod**: Manual approval required

### GitHub Environments

Configure in Settings → Environments:

- `dev`: Auto-deploy
- `staging`: Required reviewers
- `prod`: Required reviewers + wait timer

## Monitoring

### New Relic APM (Java Agent)

The Java agent is embedded in the Docker image and provides:

- Transaction tracing with method-level detail
- Error tracking with stack traces
- Database query analysis
- External service calls
- Custom metrics via API

See [docs/NEWRELIC.md](docs/NEWRELIC.md) for setup.

### CloudWatch

- **Log Group**: `/ecs/java-api-{environment}`
- **Alarms**: CPU > 80%, Memory > 80%

## Security

### Implemented

1. **Network**: Private subnets for ECS, security groups with least privilege
2. **IAM**: Separate task execution and task roles, minimal permissions
3. **Container**: Non-root user, image scanning enabled
4. **Secrets**: New Relic key in AWS Secrets Manager

### Security Groups

| Resource | Inbound | Outbound |
|----------|---------|----------|
| ALB | 80, 443 from 0.0.0.0/0 | All |
| ECS | 8080 from ALB only | All |

## Cost Optimization

| Optimization | Savings | Environments |
|--------------|---------|--------------|
| Single NAT Gateway | ~$30/month | Dev, Staging |
| Smaller Fargate tasks | Variable | Dev |
| Container Insights off | ~$3/container/month | Dev |
| ECR lifecycle policy | Storage costs | All |
| Log retention limits | Storage costs | All |

## Troubleshooting

### ECS Task Not Starting

```bash
# Check service events
aws ecs describe-services \
  --cluster java-api-dev-cluster \
  --services java-api-dev-service \
  --query 'services[0].events[:5]'
```

### Health Check Failing

```bash
# Check container logs
aws logs tail /ecs/java-api-dev --follow
```

### ALB 502/503 Errors

1. Check target group health in AWS Console
2. Verify security group allows ALB → ECS on port 8080
3. Check ECS task logs for application errors

## Required Secrets

### GitHub Repository Secrets

| Secret | Description |
|--------|-------------|
| `AWS_ROLE_ARN` | IAM role ARN for OIDC auth |

### AWS Secrets Manager

| Secret Path | Description |
|-------------|-------------|
| `java-api-{env}/newrelic` | New Relic license key |

See [docs/GITHUB_SECRETS.md](docs/GITHUB_SECRETS.md) for setup.

## License

MIT License

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a Pull Request
