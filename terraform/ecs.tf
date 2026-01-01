# ECS Cluster - terraform-aws-modules/ecs/aws v5.11.4

module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "5.11.4"

  cluster_name = "${local.name}-cluster"

  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 100
        base   = 1
      }
    }
    FARGATE_SPOT = {
      default_capacity_provider_strategy = {
        weight = 0
      }
    }
  }

  cluster_settings = {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = local.common_tags
}

# ECS Service
module "ecs_service" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "5.11.4"

  name        = "${local.name}-service"
  cluster_arn = module.ecs_cluster.arn

  cpu    = var.container_cpu
  memory = var.container_memory

  container_definitions = {
    app = {
      name      = "${local.name}-app"
      image     = "${aws_ecr_repository.app.repository_url}:latest"
      cpu       = var.container_cpu
      memory    = var.container_memory
      essential = true

      port_mappings = [
        {
          name          = "http"
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "ENVIRONMENT"
          value = var.environment
        },
        {
          name  = "NEW_RELIC_APP_NAME"
          value = var.newrelic_app_name != "" ? var.newrelic_app_name : local.name
        },
        {
          name  = "NEW_RELIC_DISTRIBUTED_TRACING_ENABLED"
          value = "true"
        }
      ]

      secrets = var.newrelic_license_key_secret_arn != "" ? [
        {
          name      = "NEW_RELIC_LICENSE_KEY"
          valueFrom = var.newrelic_license_key_secret_arn
        }
      ] : []

      health_check = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}${var.health_check_path} || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      log_configuration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }

      readonly_root_filesystem = false
    }
  }

  desired_count = var.desired_count
  launch_type   = "FARGATE"

  subnet_ids         = module.vpc.private_subnets
  security_group_ids = [module.ecs_sg.security_group_id]
  assign_public_ip   = false

  load_balancer = {
    service = {
      target_group_arn = module.alb.target_groups["ecs"].arn
      container_name   = "${local.name}-app"
      container_port   = var.container_port
    }
  }

  task_exec_iam_role_arn    = module.iam.task_execution_role_arn
  tasks_iam_role_arn        = module.iam.task_role_arn
  create_task_exec_iam_role = false
  create_tasks_iam_role     = false

  # Auto-scaling: min 1, max 3, target CPU 70%
  autoscaling_min_capacity = var.min_capacity
  autoscaling_max_capacity = var.max_capacity

  autoscaling_policies = {
    cpu = {
      policy_type = "TargetTrackingScaling"
      target_tracking_scaling_policy_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ECSServiceAverageCPUUtilization"
        }
        target_value       = var.cpu_target_value
        scale_in_cooldown  = 300
        scale_out_cooldown = 60
      }
    }
  }

  tags = local.common_tags
}
