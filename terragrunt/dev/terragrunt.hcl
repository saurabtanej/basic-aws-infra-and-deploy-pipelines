include "root" {
  path = find_in_parent_folders()
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders())}/_envcommon/app.hcl"
  expose = true
}

inputs = {
  # VPC
  vpc_cidr             = "10.0.0.0/16"
  availability_zones   = ["me-south-1a", "me-south-1b"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]

  # Cost optimization
  enable_nat_gateway        = true
  single_nat_gateway        = true
  enable_vpc_flow_logs      = false
  enable_container_insights = false

  # ECS
  container_cpu    = 256
  container_memory = 512
  desired_count    = 1
  min_capacity     = 1
  max_capacity     = 2
  cpu_target_value = 70

  # Container Insights (disabled to save costs)
  enable_container_insights = false

  # Logging
  log_retention_days = 7

  # New Relic (optional - set via environment variable or uncomment)
  # newrelic_license_key_secret_arn = "arn:aws:secretsmanager:me-south-1:ACCOUNT_ID:secret:java-api-dev/newrelic"
  # newrelic_app_name = "java-api-dev"
}


