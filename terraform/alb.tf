# ALB Module - terraform-aws-modules/alb/aws v9.12.0

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "9.12.0"

  name               = "${local.name}-alb"
  load_balancer_type = "application"
  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.public_subnets
  security_groups    = [module.alb_sg.security_group_id]

  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = "ecs"
      }
    }
  }

  target_groups = {
    ecs = {
      name             = "${local.name}-tg"
      backend_protocol = "HTTP"
      backend_port     = var.container_port
      target_type      = "ip"

      health_check = {
        enabled             = true
        healthy_threshold   = var.healthy_threshold
        unhealthy_threshold = var.unhealthy_threshold
        interval            = var.health_check_interval
        timeout             = var.health_check_timeout
        path                = var.health_check_path
        protocol            = "HTTP"
        matcher             = "200"
      }

      deregistration_delay = 30
      create_attachment    = false
    }
  }

  tags = local.common_tags
}
