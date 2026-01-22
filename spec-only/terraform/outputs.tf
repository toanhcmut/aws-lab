# VPC Outputs
output "vpc_id" {
  description = "VPC identifier"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

# ALB Outputs
output "alb_dns_name" {
  description = "ALB DNS name for accessing the application"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.main.arn
}

# ASG Outputs
output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.main.name
}

# RDS Outputs
output "rds_endpoint" {
  description = "RDS connection endpoint"
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
