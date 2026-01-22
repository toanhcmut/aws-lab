# EC2 Security Group
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-${var.environment}-ec2-sg"
  description = "Security group for EC2 instances"
  vpc_id      = module.vpc.vpc_id

  # Ingress rule allowing HTTP traffic from ALB security group only
  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
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
    Name        = "${var.project_name}-${var.environment}-ec2-sg"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Launch Template for EC2 instances
resource "aws_launch_template" "main" {
  name_prefix   = "lt-${local.name_prefix}-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  # Network interface configuration
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2.id]
    delete_on_termination       = true
  }

  # User data script (optional - can be customized)
  user_data = base64encode(<<-EOF
              #!/bin/bash
              # Basic web server setup (example)
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello from $(hostname -f)</h1>" > /var/www/html/index.html
              EOF
  )

  # Monitoring
  monitoring {
    enabled = true
  }

  # Tag specifications for instances launched from this template
  tag_specifications {
    resource_type = "instance"
    tags = merge(
      local.common_tags,
      {
        Name = "ec2-${local.name_prefix}-instance"
      }
    )
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(
      local.common_tags,
      {
        Name = "vol-${local.name_prefix}-instance"
      }
    )
  }

  tags = merge(
    local.common_tags,
    {
      Name = "lt-${local.name_prefix}"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "main" {
  name                = "asg-${local.name_prefix}-web"
  vpc_zone_identifier = module.vpc.public_subnets
  target_group_arns   = [aws_lb_target_group.main.arn]

  min_size         = var.asg_min_size
  max_size         = var.asg_max_size
  desired_capacity = var.asg_desired_capacity

  health_check_type         = "ELB"
  health_check_grace_period = 300
  force_delete              = true
  wait_for_capacity_timeout = "10m"

  # Launch template configuration
  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  # Instance refresh configuration
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  # Tags for the ASG itself
  tag {
    key                 = "Name"
    value               = "asg-${local.name_prefix}-web"
    propagate_at_launch = false
  }

  tag {
    key                 = "Project"
    value               = local.common_tags["Project"]
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = local.common_tags["Environment"]
    propagate_at_launch = true
  }

  tag {
    key                 = "CreatedBy"
    value               = local.common_tags["CreatedBy"]
    propagate_at_launch = true
  }

  tag {
    key                 = "ManagedBy"
    value               = local.common_tags["ManagedBy"]
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }

  depends_on = [
    module.vpc,
    aws_lb_target_group.main
  ]
}
