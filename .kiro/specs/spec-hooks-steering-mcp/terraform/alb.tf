# ALB Security Group
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = module.vpc.vpc_id

  # Ingress rule for HTTP traffic from internet
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Ingress rule for HTTPS traffic from internet
  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress rule for all outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-alb-sg"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "alb-${local.name_prefix}-web"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnets

  enable_deletion_protection       = false
  enable_http2                     = true
  enable_cross_zone_load_balancing = true

  tags = merge(
    local.common_tags,
    {
      Name = "alb-${local.name_prefix}-web"
    }
  )
}

# Target Group for EC2 instances
resource "aws_lb_target_group" "main" {
  name     = "tg-${local.name_prefix}-web"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  # Health check configuration
  health_check {
    enabled             = true
    healthy_threshold   = var.alb_healthy_threshold
    unhealthy_threshold = var.alb_unhealthy_threshold
    timeout             = var.alb_health_check_timeout
    interval            = var.alb_health_check_interval
    path                = var.alb_health_check_path
    protocol            = "HTTP"
    matcher             = "200"
  }

  # Deregistration delay
  deregistration_delay = 30

  # Stickiness configuration (optional)
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = false
  }

  tags = merge(
    local.common_tags,
    {
      Name = "tg-${local.name_prefix}-web"
    }
  )
}

# HTTP Listener on port 80
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  tags = merge(
    local.common_tags,
    {
      Name = "listener-${local.name_prefix}-http"
    }
  )
}
