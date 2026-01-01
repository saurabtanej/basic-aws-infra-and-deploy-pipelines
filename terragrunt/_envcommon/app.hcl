# Common Application Configuration

terraform {
  source = "${dirname(find_in_parent_folders())}/../terraform"
}

inputs = {
  health_check_path     = "/health"
  health_check_interval = 30
  health_check_timeout  = 5
  healthy_threshold     = 2
  unhealthy_threshold   = 3
  container_port        = 8080
}
