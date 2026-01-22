# Data source for available availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Local variables for resource naming
locals {
  # Use provided AZs or automatically select first 3 available
  azs = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 3)

  # Common tags applied to all resources
  common_tags = {
    Project     = "KiroDemo"
    Environment = "Lab"
    CreatedBy   = var.created_by
    ManagedBy   = "Terraform"
  }

  # Resource name prefix following naming convention: [service]-[project]-[app]-[env]
  name_prefix = "${var.project_name}-${var.app_name}-${var.environment}"
}

# VPC Module - Using official terraform-aws-modules/vpc/aws
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "vpc-${local.name_prefix}-main"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 10)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k)]

  # Disable NAT Gateways (private subnets will not have internet access)
  enable_nat_gateway     = false
  single_nat_gateway     = false
  one_nat_gateway_per_az = false

  # Enable DNS support
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Public subnet configuration
  map_public_ip_on_launch = true

  # Tags
  tags = merge(
    local.common_tags,
    {
      Name = "vpc-${local.name_prefix}-main"
    }
  )

  vpc_tags = {
    Name = "vpc-${local.name_prefix}-main"
  }

  public_subnet_tags = {
    Name = "subnet-${local.name_prefix}-public"
    Tier = "Public"
  }

  private_subnet_tags = {
    Name = "subnet-${local.name_prefix}-private"
    Tier = "Private"
  }

  public_route_table_tags = {
    Name = "rt-${local.name_prefix}-public"
  }

  private_route_table_tags = {
    Name = "rt-${local.name_prefix}-private"
  }

  igw_tags = {
    Name = "igw-${local.name_prefix}-main"
  }
}
