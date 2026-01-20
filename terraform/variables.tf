# Project Configuration
variable "project" {
  description = "Project name"
  type        = string
  default     = "tilt"
}

variable "app" {
  description = "Application name"
  type        = string
  default     = "sensor"
}

variable "env" {
  description = "Environment name"
  type        = string
  default     = "lab"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# Network Configuration
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

# Ingestion Configuration
variable "ingestion_schedule_expression" {
  description = "EventBridge schedule for ingestion"
  type        = string
  default     = "rate(5 minutes)"
}

variable "sync_schedule_expression" {
  description = "EventBridge schedule for data sync"
  type        = string
  default     = "rate(5 minutes)"
}

# Lambda Configuration
variable "lambda_parsing_memory" {
  description = "Memory for Lambda_Parsing function (MB)"
  type        = number
  default     = 512
}

variable "lambda_parsing_timeout" {
  description = "Timeout for Lambda_Parsing function (seconds)"
  type        = number
  default     = 60
}

variable "lambda_distributing_memory" {
  description = "Memory for Lambda_Distributing function (MB)"
  type        = number
  default     = 256
}

variable "lambda_distributing_timeout" {
  description = "Timeout for Lambda_Distributing function (seconds)"
  type        = number
  default     = 30
}

variable "lambda_db1_memory" {
  description = "Memory for Lambda_DB1 function (MB)"
  type        = number
  default     = 512
}

variable "lambda_db1_timeout" {
  description = "Timeout for Lambda_DB1 function (seconds)"
  type        = number
  default     = 120
}

variable "lambda_sync_memory" {
  description = "Memory for Lambda_Sync function (MB)"
  type        = number
  default     = 512
}

variable "lambda_sync_timeout" {
  description = "Timeout for Lambda_Sync function (seconds)"
  type        = number
  default     = 120
}

variable "lambda_command_handler_memory" {
  description = "Memory for Command Handler functions (MB)"
  type        = number
  default     = 256
}

variable "lambda_command_handler_timeout" {
  description = "Timeout for Command Handler functions (seconds)"
  type        = number
  default     = 30
}

# ECS Configuration
variable "ecs_task_cpu" {
  description = "CPU units for ECS task"
  type        = number
  default     = 512
}

variable "ecs_task_memory" {
  description = "Memory for ECS task (MB)"
  type        = number
  default     = 1024
}

variable "ecs_desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2
}

# RDS Configuration
variable "aurora_engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
  default     = "15.4"
}

variable "aurora_min_capacity" {
  description = "Minimum Aurora capacity (ACU)"
  type        = number
  default     = 0.5
}

variable "aurora_max_capacity" {
  description = "Maximum Aurora capacity (ACU)"
  type        = number
  default     = 2
}

variable "aurora_backup_retention_days" {
  description = "Aurora backup retention period (days)"
  type        = number
  default     = 7
}

# ElastiCache Configuration
variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.0"
}

variable "redis_node_type" {
  description = "Redis node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_num_cache_nodes" {
  description = "Number of Redis cache nodes"
  type        = number
  default     = 2
}

# EC2 Configuration
variable "ec2_instance_type" {
  description = "EC2 instance type for Portal API"
  type        = string
  default     = "t3.medium"
}

variable "ec2_min_size" {
  description = "Minimum number of EC2 instances"
  type        = number
  default     = 2
}

variable "ec2_max_size" {
  description = "Maximum number of EC2 instances"
  type        = number
  default     = 4
}

variable "ec2_desired_capacity" {
  description = "Desired number of EC2 instances"
  type        = number
  default     = 2
}

# SQS Configuration
variable "sqs_visibility_timeout_fifo" {
  description = "Visibility timeout for FIFO queues (seconds)"
  type        = number
  default     = 90
}

variable "sqs_visibility_timeout_standard" {
  description = "Visibility timeout for Standard queues (seconds)"
  type        = number
  default     = 120
}

variable "sqs_message_retention_seconds" {
  description = "Message retention period (seconds)"
  type        = number
  default     = 345600 # 4 days
}

variable "sqs_max_receive_count" {
  description = "Maximum receive count before moving to DLQ"
  type        = number
  default     = 3
}

# Tags
variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "TiltSensor"
    Environment = "Lab"
    CreatedBy   = "Kiro-Intern"
    ManagedBy   = "Terraform"
  }
}
