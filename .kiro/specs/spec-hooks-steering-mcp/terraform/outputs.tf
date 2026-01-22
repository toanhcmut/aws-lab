# VPC Outputs
output "vpc_id" {
  description = "VPC identifier"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnets
}

output "availability_zones" {
  description = "List of availability zones used"
  value       = module.vpc.azs
}

# ALB Outputs
output "alb_id" {
  description = "ALB identifier"
  value       = aws_lb.main.id
}

output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "ALB DNS name for accessing the application"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "ALB Route53 zone ID"
  value       = aws_lb.main.zone_id
}

output "alb_security_group_id" {
  description = "ALB security group ID"
  value       = aws_security_group.alb.id
}

output "target_group_arn" {
  description = "Target group ARN"
  value       = aws_lb_target_group.main.arn
}

# ASG Outputs
output "asg_id" {
  description = "Auto Scaling Group identifier"
  value       = aws_autoscaling_group.main.id
}

output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.main.name
}

output "asg_arn" {
  description = "Auto Scaling Group ARN"
  value       = aws_autoscaling_group.main.arn
}

output "launch_template_id" {
  description = "Launch template ID"
  value       = aws_launch_template.main.id
}

output "ec2_security_group_id" {
  description = "EC2 security group ID"
  value       = aws_security_group.ec2.id
}

# RDS Outputs
output "rds_instance_id" {
  description = "RDS instance identifier"
  value       = aws_db_instance.main.id
}

output "rds_endpoint" {
  description = "RDS connection endpoint (hostname:port)"
  value       = aws_db_instance.main.endpoint
}

output "rds_address" {
  description = "RDS hostname"
  value       = aws_db_instance.main.address
}

output "rds_port" {
  description = "RDS port number"
  value       = aws_db_instance.main.port
}

output "rds_arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.main.arn
}

output "rds_security_group_id" {
  description = "RDS security group ID"
  value       = aws_security_group.rds.id
}

output "db_subnet_group_name" {
  description = "RDS subnet group name"
  value       = aws_db_subnet_group.main.name
}
