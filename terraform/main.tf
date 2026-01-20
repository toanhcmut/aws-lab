# IoT Tilt Sensor Monitoring System - Main Terraform Configuration

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  project            = var.project
  app                = var.app
  env                = var.env
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  common_tags        = var.common_tags
}

# IAM Module
module "iam" {
  source = "./modules/iam"

  project     = var.project
  app         = var.app
  env         = var.env
  common_tags = var.common_tags

  # SQS Queue ARNs (will be provided by SQS module)
  sqs_fifo_distributing_arn = module.sqs.fifo_distributing_arn
  sqs_db1_arn               = module.sqs.db1_arn
  sqs_mqtt_command_arn      = module.sqs.mqtt_command_arn
  sqs_lorawan_command_arn   = module.sqs.lorawan_command_arn

  # RDS Cluster ARN (will be provided by RDS module)
  aurora_cluster_arn = module.rds.cluster_arn
}

# SQS Module
module "sqs" {
  source = "./modules/sqs"

  project                       = var.project
  app                           = var.app
  env                           = var.env
  visibility_timeout_fifo       = var.sqs_visibility_timeout_fifo
  visibility_timeout_standard   = var.sqs_visibility_timeout_standard
  message_retention_seconds     = var.sqs_message_retention_seconds
  max_receive_count             = var.sqs_max_receive_count
  common_tags                   = var.common_tags
}

# RDS Module (Aurora PostgreSQL)
module "rds" {
  source = "./modules/rds"

  project                  = var.project
  app                      = var.app
  env                      = var.env
  vpc_id                   = module.vpc.vpc_id
  private_subnet_ids       = module.vpc.private_subnet_ids
  engine_version           = var.aurora_engine_version
  min_capacity             = var.aurora_min_capacity
  max_capacity             = var.aurora_max_capacity
  backup_retention_days    = var.aurora_backup_retention_days
  lambda_db1_sg_id         = module.lambda.db1_security_group_id
  lambda_sync_sg_id        = module.lambda.sync_security_group_id
  ec2_portal_sg_id         = module.ec2.portal_security_group_id
  common_tags              = var.common_tags
}

# ElastiCache Module (Redis)
module "elasticache" {
  source = "./modules/elasticache"

  project            = var.project
  app                = var.app
  env                = var.env
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  engine_version     = var.redis_engine_version
  node_type          = var.redis_node_type
  num_cache_nodes    = var.redis_num_cache_nodes
  lambda_sync_sg_id  = module.lambda.sync_security_group_id
  ec2_portal_sg_id   = module.ec2.portal_security_group_id
  common_tags        = var.common_tags
}

# ECS Module (Message Broker)
module "ecs" {
  source = "./modules/ecs"

  project              = var.project
  app                  = var.app
  env                  = var.env
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  task_cpu             = var.ecs_task_cpu
  task_memory          = var.ecs_task_memory
  desired_count        = var.ecs_desired_count
  nlb_target_group_arn = module.nlb.target_group_arn
  lambda_parsing_sg_id = module.lambda.parsing_security_group_id
  lambda_mqtt_cmd_sg_id    = module.lambda.mqtt_command_handler_security_group_id
  lambda_lorawan_cmd_sg_id = module.lambda.lorawan_command_handler_security_group_id
  common_tags          = var.common_tags
}

# NLB Module
module "nlb" {
  source = "./modules/nlb"

  project            = var.project
  app                = var.app
  env                = var.env
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  ecs_security_group_id = module.ecs.broker_security_group_id
  common_tags        = var.common_tags
}

# Lambda Module
module "lambda" {
  source = "./modules/lambda"

  project     = var.project
  app         = var.app
  env         = var.env
  vpc_id      = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  # Lambda Configuration
  parsing_memory              = var.lambda_parsing_memory
  parsing_timeout             = var.lambda_parsing_timeout
  distributing_memory         = var.lambda_distributing_memory
  distributing_timeout        = var.lambda_distributing_timeout
  db1_memory                  = var.lambda_db1_memory
  db1_timeout                 = var.lambda_db1_timeout
  sync_memory                 = var.lambda_sync_memory
  sync_timeout                = var.lambda_sync_timeout
  command_handler_memory      = var.lambda_command_handler_memory
  command_handler_timeout     = var.lambda_command_handler_timeout

  # IAM Roles
  lambda_parsing_role_arn         = module.iam.lambda_parsing_role_arn
  lambda_distributing_role_arn    = module.iam.lambda_distributing_role_arn
  lambda_db1_role_arn             = module.iam.lambda_db1_role_arn
  lambda_sync_role_arn            = module.iam.lambda_sync_role_arn
  lambda_mqtt_cmd_handler_role_arn    = module.iam.lambda_mqtt_cmd_handler_role_arn
  lambda_lorawan_cmd_handler_role_arn = module.iam.lambda_lorawan_cmd_handler_role_arn

  # SQS Queue URLs
  sqs_fifo_distributing_url = module.sqs.fifo_distributing_url
  sqs_db1_url               = module.sqs.db1_url
  sqs_mqtt_command_url      = module.sqs.mqtt_command_url
  sqs_lorawan_command_url   = module.sqs.lorawan_command_url

  # SQS Queue ARNs
  sqs_fifo_distributing_arn = module.sqs.fifo_distributing_arn
  sqs_db1_arn               = module.sqs.db1_arn
  sqs_mqtt_command_arn      = module.sqs.mqtt_command_arn
  sqs_lorawan_command_arn   = module.sqs.lorawan_command_arn

  # Database and Cache Endpoints
  aurora_endpoint = module.rds.cluster_endpoint
  redis_endpoint  = module.elasticache.primary_endpoint

  # ECS Broker Endpoint
  ecs_broker_endpoint = module.ecs.broker_endpoint

  # Security Group IDs
  ecs_broker_sg_id  = module.ecs.broker_security_group_id
  aurora_sg_id      = module.rds.security_group_id
  redis_sg_id       = module.elasticache.security_group_id

  common_tags = var.common_tags
}

# EventBridge Module
module "eventbridge" {
  source = "./modules/eventbridge"

  project                       = var.project
  app                           = var.app
  env                           = var.env
  ingestion_schedule_expression = var.ingestion_schedule_expression
  sync_schedule_expression      = var.sync_schedule_expression
  lambda_parsing_function_arn   = module.lambda.parsing_function_arn
  lambda_parsing_function_name  = module.lambda.parsing_function_name
  lambda_sync_function_arn      = module.lambda.sync_function_arn
  lambda_sync_function_name     = module.lambda.sync_function_name
  common_tags                   = var.common_tags
}

# EC2 Module (Portal API)
module "ec2" {
  source = "./modules/ec2"

  project            = var.project
  app                = var.app
  env                = var.env
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  instance_type      = var.ec2_instance_type
  min_size           = var.ec2_min_size
  max_size           = var.ec2_max_size
  desired_capacity   = var.ec2_desired_capacity
  alb_target_group_arn = module.alb.target_group_arn
  iam_instance_profile_name = module.iam.ec2_instance_profile_name
  alb_security_group_id = module.alb.security_group_id
  aurora_sg_id       = module.rds.security_group_id
  redis_sg_id        = module.elasticache.security_group_id
  sqs_mqtt_command_arn    = module.sqs.mqtt_command_arn
  sqs_lorawan_command_arn = module.sqs.lorawan_command_arn
  common_tags        = var.common_tags
}

# ALB Module
module "alb" {
  source = "./modules/alb"

  project            = var.project
  app                = var.app
  env                = var.env
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  ec2_security_group_id = module.ec2.portal_security_group_id
  common_tags        = var.common_tags
}

# WAF Module
module "waf" {
  source = "./modules/waf"

  project     = var.project
  app         = var.app
  env         = var.env
  common_tags = var.common_tags
}

# CloudFront Module
module "cloudfront" {
  source = "./modules/cloudfront"

  project         = var.project
  app             = var.app
  env             = var.env
  alb_dns_name    = module.alb.dns_name
  waf_web_acl_arn = module.waf.web_acl_arn
  common_tags     = var.common_tags
}
