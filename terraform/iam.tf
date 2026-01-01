# IAM Roles - Custom module for least privilege
module "iam" {
  source = "./modules/iam"

  name_prefix   = local.name
  ecr_repo_arn  = aws_ecr_repository.app.arn
  log_group_arn = aws_cloudwatch_log_group.app.arn
  aws_region    = var.aws_region

  tags = local.common_tags
}
