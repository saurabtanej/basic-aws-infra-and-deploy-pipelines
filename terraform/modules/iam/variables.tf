variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "ecr_repo_arn" {
  description = "ARN of the ECR repository"
  type        = string
}

variable "log_group_arn" {
  description = "ARN of the CloudWatch Log Group"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
