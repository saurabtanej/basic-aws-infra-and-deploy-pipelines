resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${local.name}"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    Name = "${local.name}-logs"
  })
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${local.name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU utilization is above 80%"

  dimensions = {
    ClusterName = module.ecs_cluster.name
    ServiceName = module.ecs_service.name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "memory_high" {
  alarm_name          = "${local.name}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Memory utilization is above 80%"

  dimensions = {
    ClusterName = module.ecs_cluster.name
    ServiceName = module.ecs_service.name
  }

  tags = local.common_tags
}
