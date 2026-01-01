include "root" {
  path = find_in_parent_folders()
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders())}/_envcommon/app.hcl"
  expose = true
}

inputs = {
  # VPC
  vpc_cidr             = "10.1.0.0/16"
  availability_zones   = ["me-south-1a", "me-south-1b"]
  public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnet_cidrs = ["10.1.10.0/24", "10.1.20.0/24"]

  # NAT Gateway
  enable_nat_gateway        = true
  single_nat_gateway        = true
  enable_vpc_flow_logs      = true
  enable_container_insights = true

  # ECS - production-like
  container_cpu    = 512
  container_memory = 1024
  desired_count    = 2
  min_capacity     = 1
  max_capacity     = 3
  cpu_target_value = 70

  # Logging
  log_retention_days = 14
}
