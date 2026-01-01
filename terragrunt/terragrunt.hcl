# Root Terragrunt Configuration

remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket         = "terraform-state-${get_aws_account_id()}-${local.aws_region}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.aws_region
    encrypt        = true
    dynamodb_table = "terraform-state-lock"

    s3_bucket_tags = {
      Name      = "Terraform State"
      ManagedBy = "Terragrunt"
    }
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80.0"
    }
  }
}

provider "aws" {
  region = "${local.aws_region}"

  default_tags {
    tags = {
      Project     = "${local.project_name}"
      Environment = "${local.environment}"
      ManagedBy   = "Terraform"
    }
  }
}
EOF
}

locals {
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl", "env.hcl"), { locals = {} })
  aws_region   = try(local.env_vars.locals.aws_region, "me-south-1")
  environment  = try(local.env_vars.locals.environment, "dev")
  project_name = "java-api"
}

inputs = {
  project_name = local.project_name
  aws_region   = local.aws_region
  environment  = local.environment
}
