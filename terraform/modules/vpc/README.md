# VPC Module

This module creates a Virtual Private Cloud (VPC) with public and private subnets across multiple availability zones.

## Features

- VPC with configurable CIDR block
- Public subnets for load balancers and internet-facing resources
- Private subnets for compute and storage resources
- Internet Gateway for public subnet internet access
- NAT Gateway for private subnet outbound internet access (optional)
- DNS support enabled
- Proper tagging following project naming conventions

## Usage

```hcl
module "vpc" {
  source = "./modules/vpc"

  project            = "tilt"
  app                = "sensor"
  env                = "lab"
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
  common_tags        = {
    Project     = "TiltSensor"
    Environment = "Lab"
    ManagedBy   = "Terraform"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project | Project name | string | - | yes |
| app | Application name | string | - | yes |
| env | Environment name | string | - | yes |
| vpc_cidr | VPC CIDR block | string | - | yes |
| availability_zones | List of availability zones | list(string) | - | yes |
| public_subnet_cidrs | Public subnet CIDR blocks | list(string) | - | yes |
| private_subnet_cidrs | Private subnet CIDR blocks | list(string) | - | yes |
| common_tags | Common tags for all resources | map(string) | - | yes |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | VPC ID |
| vpc_cidr_block | VPC CIDR block |
| public_subnet_ids | List of public subnet IDs |
| private_subnet_ids | List of private subnet IDs |
| public_route_table_ids | List of public route table IDs |
| private_route_table_ids | List of private route table IDs |
| internet_gateway_id | Internet Gateway ID |
| nat_gateway_ids | List of NAT Gateway IDs |

## Resources Created

- 1 VPC
- 2 Public Subnets (across 2 AZs)
- 2 Private Subnets (across 2 AZs)
- 1 Internet Gateway
- 1 NAT Gateway (optional, can be disabled to save costs)
- Route tables and associations

## Naming Convention

All resources follow the naming pattern: `[service]-[project]-[app]-[env]-[purpose]`

Example:
- VPC: `vpc-tilt-sensor-lab`
- Subnet: `subnet-tilt-sensor-lab-public-az1`
- IGW: `igw-tilt-sensor-lab`

## Cost Optimization

- NAT Gateway is configured as single NAT (not HA) to reduce costs
- VPC Flow Logs are disabled by default (can be enabled if needed)
- Consider using VPC Endpoints for AWS services to reduce NAT Gateway data transfer costs
