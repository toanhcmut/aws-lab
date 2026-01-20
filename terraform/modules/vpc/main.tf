# VPC Module using terraform-aws-modules/vpc/aws
# This module creates a VPC with public and private subnets across multiple AZs

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "vpc-${var.project}-${var.app}-${var.env}"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs

  # Enable DNS support
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Enable NAT Gateway for private subnets (optional - can be disabled to save costs)
  enable_nat_gateway = true
  single_nat_gateway = true # Use single NAT Gateway to save costs (not HA)

  # Enable VPC Flow Logs (optional)
  enable_flow_log                      = false
  create_flow_log_cloudwatch_iam_role  = false
  create_flow_log_cloudwatch_log_group = false

  # Public subnet tags
  public_subnet_tags = {
    Name = "subnet-${var.project}-${var.app}-${var.env}-public"
    Tier = "Public"
  }

  # Private subnet tags
  private_subnet_tags = {
    Name = "subnet-${var.project}-${var.app}-${var.env}-private"
    Tier = "Private"
  }

  # VPC tags
  tags = merge(
    var.common_tags,
    {
      Name = "vpc-${var.project}-${var.app}-${var.env}"
    }
  )

  # Internet Gateway tags
  igw_tags = {
    Name = "igw-${var.project}-${var.app}-${var.env}"
  }

  # NAT Gateway tags
  nat_gateway_tags = {
    Name = "nat-${var.project}-${var.app}-${var.env}"
  }

  # Route table tags
  public_route_table_tags = {
    Name = "rt-${var.project}-${var.app}-${var.env}-public"
  }

  private_route_table_tags = {
    Name = "rt-${var.project}-${var.app}-${var.env}-private"
  }
}

# VPC Endpoints for AWS Services (optional - reduces NAT Gateway costs)
# Uncomment if you want to use VPC endpoints for SQS, Lambda, etc.

# resource "aws_vpc_endpoint" "sqs" {
#   vpc_id            = module.vpc.vpc_id
#   service_name      = "com.amazonaws.${data.aws_region.current.name}.sqs"
#   vpc_endpoint_type = "Interface"
#
#   subnet_ids         = module.vpc.private_subnets
#   security_group_ids = [aws_security_group.vpc_endpoints.id]
#
#   private_dns_enabled = true
#
#   tags = merge(
#     var.common_tags,
#     {
#       Name = "vpce-${var.project}-${var.app}-${var.env}-sqs"
#     }
#   )
# }

# data "aws_region" "current" {}
