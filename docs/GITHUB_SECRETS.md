# GitHub Secrets Configuration

This document describes all the GitHub secrets required for the CI/CD pipeline.

## Required Secrets

### AWS Authentication (OIDC - Recommended)

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `AWS_ROLE_ARN` | IAM Role ARN for GitHub OIDC | `arn:aws:iam::123456789012:role/github-actions-role` |

### AWS Authentication (Access Keys - Alternative)

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | AWS Access Key ID | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | AWS Secret Access Key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |

### Environment-Specific (Optional)

| Secret Name | Description | Environment |
|-------------|-------------|-------------|
| `AWS_ROLE_ARN_STAGING` | IAM Role for staging account | Staging |
| `AWS_ROLE_ARN_PROD` | IAM Role for production account | Production |

## Setting Up OIDC Authentication (Recommended)

### 1. Create OIDC Provider in AWS

```bash
# Create the OIDC provider
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### 2. Create IAM Role

Create a role with the following trust policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_ORG/basic-aws-infra-and-deploy-pipelines:*"
        }
      }
    }
  ]
}
```

### 3. Attach Permissions

Attach a policy with the following permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRAccess",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ECSAccess",
      "Effect": "Allow",
      "Action": [
        "ecs:DescribeServices",
        "ecs:UpdateService",
        "ecs:DescribeTaskDefinition",
        "ecs:RegisterTaskDefinition",
        "ecs:DescribeTasks",
        "ecs:ListTasks"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ELBAccess",
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:DescribeTargetGroups",
        "elasticloadbalancing:DescribeTargetHealth"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IAMPassRole",
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": [
        "arn:aws:iam::*:role/*-task-execution-role",
        "arn:aws:iam::*:role/*-task-role"
      ]
    },
    {
      "Sid": "CloudWatchLogs",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:log-group:/ecs/*"
    }
  ]
}
```

### 4. Add Secret to GitHub

1. Go to your repository → Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Name: `AWS_ROLE_ARN`
4. Value: `arn:aws:iam::ACCOUNT_ID:role/github-actions-role`

## Environment Configuration

### Creating Environments

1. Go to Settings → Environments
2. Create environments: `dev`, `staging`, `prod`
3. Configure protection rules:

| Environment | Protection Rules |
|-------------|------------------|
| dev | None (auto-deploy) |
| staging | Required reviewers |
| prod | Required reviewers + Wait timer |

### Environment-Specific Secrets

Each environment can have its own secrets:

1. Click on the environment
2. Add environment secrets
3. These override repository secrets

## Verification

### Test OIDC Authentication

Create a test workflow:

```yaml
name: Test AWS OIDC
on:
  workflow_dispatch:

jobs:
  test:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: me-south-1  # Bahrain
      
      - name: Verify
        run: aws sts get-caller-identity
```

## Troubleshooting

### "Not authorized to perform: sts:AssumeRoleWithWebIdentity"

1. Check the OIDC provider thumbprint
2. Verify the trust policy conditions
3. Ensure the repository name matches exactly

### "Could not assume role"

1. Verify the role ARN is correct
2. Check IAM role permissions
3. Verify GitHub Actions has `id-token: write` permission

## Security Best Practices

1. **Use OIDC** over access keys when possible
2. **Scope permissions** to specific resources
3. **Use separate roles** for each environment
4. **Rotate credentials** regularly if using access keys
5. **Audit role usage** with CloudTrail

