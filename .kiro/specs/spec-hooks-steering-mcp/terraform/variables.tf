# Project Configuration
variable "project_name" {
  description = "Project name for resource naming (e.g., 'tilt')"
  type        = string
  default     = "tilt"
}

variable "app_name" {
  description = "Application name for resource naming (e.g., 'sensor')"
  type        = string
  default     = "sensor"
}

variable "environment" {
  description = "Environment name (e.g., 'lab', 'dev', 'prod')"
  type        = string
  default     = "lab"
}

variable "created_by" {
  description = "Creator name for tagging"
  type        = string
  default     = "Toan-Tran"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "List of availability zones (must be exactly 3)"
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.availability_zones) == 0 || length(var.availability_zones) == 3
    error_message = "Either provide exactly 3 availability zones or leave empty for automatic selection."
  }
}

# ALB Configuration
variable "alb_health_check_path" {
  description = "Health check path for ALB target group"
  type        = string
  default     = "/"
}

variable "alb_health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30

  validation {
    condition     = var.alb_health_check_interval >= 5 && var.alb_health_check_interval <= 300
    error_message = "Health check interval must be between 5 and 300 seconds."
  }
}

variable "alb_health_check_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 5

  validation {
    condition     = var.alb_health_check_timeout >= 2 && var.alb_health_check_timeout <= 120
    error_message = "Health check timeout must be between 2 and 120 seconds."
  }
}

variable "alb_healthy_threshold" {
  description = "Number of consecutive health checks successes required"
  type        = number
  default     = 2

  validation {
    condition     = var.alb_healthy_threshold >= 2 && var.alb_healthy_threshold <= 10
    error_message = "Healthy threshold must be between 2 and 10."
  }
}

variable "alb_unhealthy_threshold" {
  description = "Number of consecutive health check failures required"
  type        = number
  default     = 2

  validation {
    condition     = var.alb_unhealthy_threshold >= 2 && var.alb_unhealthy_threshold <= 10
    error_message = "Unhealthy threshold must be between 2 and 10."
  }
}

# EC2 Configuration
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
}

# Auto Scaling Configuration
variable "asg_min_size" {
  description = "Minimum number of instances in ASG"
  type        = number
  default     = 3

  validation {
    condition     = var.asg_min_size >= 1
    error_message = "Minimum ASG size must be at least 1."
  }
}

variable "asg_max_size" {
  description = "Maximum number of instances in ASG"
  type        = number
  default     = 9

  validation {
    condition     = var.asg_max_size >= 1
    error_message = "Maximum ASG size must be at least 1."
  }
}

variable "asg_desired_capacity" {
  description = "Desired number of instances in ASG"
  type        = number
  default     = 3

  validation {
    condition     = var.asg_desired_capacity >= 1
    error_message = "Desired capacity must be at least 1."
  }
}

# RDS Configuration
variable "db_engine" {
  description = "Database engine (mysql, postgres, mariadb, etc.)"
  type        = string
  default     = "mysql"

  validation {
    condition     = contains(["mysql", "postgres", "mariadb", "oracle-se2", "sqlserver-ex"], var.db_engine)
    error_message = "Database engine must be one of: mysql, postgres, mariadb, oracle-se2, sqlserver-ex."
  }
}

variable "db_engine_version" {
  description = "Database engine version"
  type        = string
  default     = "8.0"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20

  validation {
    condition     = var.db_allocated_storage >= 20 && var.db_allocated_storage <= 65536
    error_message = "Allocated storage must be between 20 and 65536 GB."
  }
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_username" {
  description = "Database master username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 8
    error_message = "Database password must be at least 8 characters long."
  }
}

variable "db_backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7

  validation {
    condition     = var.db_backup_retention_period >= 0 && var.db_backup_retention_period <= 35
    error_message = "Backup retention period must be between 0 and 35 days."
  }
}

variable "db_skip_final_snapshot" {
  description = "Skip final snapshot when destroying RDS instance"
  type        = bool
  default     = true
}
