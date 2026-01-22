# RDS Security Group
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Security group for RDS database"
  vpc_id      = module.vpc.vpc_id

  # Ingress rule allowing database traffic from EC2 security group only
  # Port is determined by database engine
  ingress {
    description     = "${upper(var.db_engine)} from EC2"
    from_port       = local.db_port
    to_port         = local.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-rds-sg"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Local variable for database port based on engine
locals {
  db_port = (
    var.db_engine == "mysql" ? 3306 :
    var.db_engine == "postgres" ? 5432 :
    var.db_engine == "mariadb" ? 3306 :
    var.db_engine == "oracle-se2" ? 1521 :
    var.db_engine == "sqlserver-ex" ? 1433 :
    3306 # default to MySQL port
  )
}

# RDS Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "dbsubnet-${local.name_prefix}-main"
  subnet_ids = module.vpc.private_subnets

  description = "Database subnet group for ${local.name_prefix}"

  tags = merge(
    local.common_tags,
    {
      Name = "dbsubnet-${local.name_prefix}-main"
    }
  )
}

# RDS Instance with Multi-AZ
resource "aws_db_instance" "main" {
  identifier = "rds-${local.name_prefix}-db"

  # Engine configuration
  engine         = var.db_engine
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  # Storage configuration
  allocated_storage     = var.db_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  max_allocated_storage = var.db_allocated_storage * 2

  # Database configuration
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = local.db_port

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # High Availability configuration
  multi_az = true

  # Backup configuration
  backup_retention_period = var.db_backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  # Snapshot configuration
  skip_final_snapshot       = var.db_skip_final_snapshot
  final_snapshot_identifier = var.db_skip_final_snapshot ? null : "rds-${local.name_prefix}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Performance Insights
  enabled_cloudwatch_logs_exports = var.db_engine == "mysql" ? ["error", "general", "slowquery"] : var.db_engine == "postgres" ? ["postgresql"] : []

  # Deletion protection (set to true for production)
  deletion_protection = false

  # Auto minor version upgrade
  auto_minor_version_upgrade = true

  # Copy tags to snapshots
  copy_tags_to_snapshot = true

  tags = merge(
    local.common_tags,
    {
      Name = "rds-${local.name_prefix}-db"
    }
  )

  depends_on = [
    aws_db_subnet_group.main
  ]

  lifecycle {
    ignore_changes = [
      final_snapshot_identifier,
      password
    ]
  }
}
