# Network Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

# Load Balancer Outputs
output "nlb_dns_name" {
  description = "NLB DNS name for IoT devices"
  value       = module.nlb.dns_name
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.alb.dns_name
}

# Database Outputs
output "aurora_endpoint" {
  description = "Aurora cluster endpoint"
  value       = module.rds.cluster_endpoint
  sensitive   = true
}

output "aurora_reader_endpoint" {
  description = "Aurora reader endpoint"
  value       = module.rds.reader_endpoint
  sensitive   = true
}

output "redis_primary_endpoint" {
  description = "Redis primary endpoint"
  value       = module.elasticache.primary_endpoint
  sensitive   = true
}

output "redis_reader_endpoint" {
  description = "Redis reader endpoint"
  value       = module.elasticache.reader_endpoint
  sensitive   = true
}

# CloudFront Output
output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = module.cloudfront.domain_name
}

# SQS Outputs
output "sqs_fifo_distributing_url" {
  description = "SQS FIFO distributing queue URL"
  value       = module.sqs.fifo_distributing_url
}

output "sqs_db1_url" {
  description = "SQS DB1 queue URL"
  value       = module.sqs.db1_url
}

output "sqs_mqtt_command_url" {
  description = "SQS MQTT command queue URL"
  value       = module.sqs.mqtt_command_url
}

output "sqs_lorawan_command_url" {
  description = "SQS LoRaWAN command queue URL"
  value       = module.sqs.lorawan_command_url
}

# ECS Outputs
output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = module.ecs.service_name
}

# Lambda Outputs
output "lambda_parsing_function_name" {
  description = "Lambda Parsing function name"
  value       = module.lambda.parsing_function_name
}

output "lambda_distributing_function_name" {
  description = "Lambda Distributing function name"
  value       = module.lambda.distributing_function_name
}

output "lambda_db1_function_name" {
  description = "Lambda DB1 function name"
  value       = module.lambda.db1_function_name
}

output "lambda_sync_function_name" {
  description = "Lambda Sync function name"
  value       = module.lambda.sync_function_name
}
