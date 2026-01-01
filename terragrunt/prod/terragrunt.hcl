include "root" {
  path = find_in_parent_folders()
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders())}/_envcommon/app.hcl"
  expose = true
}

inputs = {
  # VPC - 3 AZs for high availability
  vpc_cidr             = "10.2.0.0/16"
  availability_zones   = ["me-south-1a", "me-south-1b", "me-south-1c"]
  public_subnet_cidrs  = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
  private_subnet_cidrs = ["10.2.10.0/24", "10.2.20.0/24", "10.2.30.0/24"]

  # High availability - one NAT per AZ
  enable_nat_gateway        = true
  single_nat_gateway        = false
  enable_vpc_flow_logs      = true
  enable_container_insights = true

  # ECS - production scale
  container_cpu    = 1024
  container_memory = 2048
  desired_count    = 2
  min_capacity     = 2
  max_capacity     = 10
  cpu_target_value = 70

  # Logging
  log_retention_days = 30
}
