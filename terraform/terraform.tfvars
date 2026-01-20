# Project Configuration
project = "tilt"
app     = "sensor"
env     = "lab"
region  = "us-east-1"

# Network Configuration
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

# Ingestion Configuration
ingestion_schedule_expression = "rate(5 minutes)"
sync_schedule_expression      = "rate(5 minutes)"

# Lambda Configuration
lambda_parsing_memory       = 512
lambda_parsing_timeout      = 60
lambda_distributing_memory  = 256
lambda_distributing_timeout = 30
lambda_db1_memory           = 512
lambda_db1_timeout          = 120
lambda_sync_memory          = 512
lambda_sync_timeout         = 120
lambda_command_handler_memory  = 256
lambda_command_handler_timeout = 30

# ECS Configuration
ecs_task_cpu      = 512
ecs_task_memory   = 1024
ecs_desired_count = 2

# RDS Configuration
aurora_engine_version       = "15.4"
aurora_min_capacity         = 0.5
aurora_max_capacity         = 2
aurora_backup_retention_days = 7

# ElastiCache Configuration
redis_engine_version  = "7.0"
redis_node_type       = "cache.t3.micro"
redis_num_cache_nodes = 2

# EC2 Configuration
ec2_instance_type    = "t3.medium"
ec2_min_size         = 2
ec2_max_size         = 4
ec2_desired_capacity = 2

# SQS Configuration
sqs_visibility_timeout_fifo     = 90
sqs_visibility_timeout_standard = 120
sqs_message_retention_seconds   = 345600 # 4 days
sqs_max_receive_count           = 3

# Tags
common_tags = {
  Project     = "TiltSensor"
  Environment = "Lab"
  CreatedBy   = "Kiro-Intern"
  ManagedBy   = "Terraform"
}
