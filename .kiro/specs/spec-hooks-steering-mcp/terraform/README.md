# Terraform 3-Tier AWS Architecture with High Availability

This Terraform configuration creates a production-ready, highly available 3-tier AWS architecture with resources distributed across 3 Availability Zones using official Terraform AWS modules.

## Architecture Overview

The infrastructure consists of:

1. **Network Layer**: VPC with 3 public subnets and 3 private subnets across 3 AZs
2. **Application Layer**: Auto Scaling Group (3-9 instances) behind an Application Load Balancer
3. **Data Layer**: Multi-AZ RDS database instance in private subnets

```
Internet
    |
    v
[Internet Gateway]
    |
    v
[Application Load Balancer] (Public Subnets across 3 AZs)
    |
    v
[Auto Scaling Group - EC2 Instances] (Public Subnets - 3 AZs)
    |
    v
[RDS Multi-AZ Database] (Private Subnets - 3 AZs - No Internet Access)
```

## Features

- **High Availability**: All resources span 3 Availability Zones
- **Auto Scaling**: EC2 instances scale from 3 to 9 instances based on demand (configurable)
- **Load Balancing**: Application Load Balancer with HTTP listener and health checks
- **Database Redundancy**: Multi-AZ RDS with automated backups
- **Security**: Layered security groups with least privilege access using security group references
- **Network Isolation**: Public subnets for web tier, private subnets for database tier (no internet access)
- **Dynamic AZ Selection**: Automatically queries available AZs in the region
- **Official Modules**: Uses terraform-aws-modules/vpc for VPC infrastructure
- **Best Practices**: Follows AWS and Terraform best practices with proper tagging

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate credentials
- An AWS account with necessary permissions
- At least 3 Availability Zones available in your target AWS region

## Quick Start

1. **Clone or copy the Terraform files to your project directory**

2. **Create a `terraform.tfvars` file** (use `terraform.tfvars.example` as a template):

```hcl
# Project Configuration
project_name = "tilt"
app_name     = "sensor"
environment  = "lab"
created_by   = "Toan-Tran"

# VPC Configuration
vpc_cidr = "10.0.0.0/16"

# EC2 Configuration
instance_type = "t3.micro"
ami_id        = "ami-0c55b159cbfafe1f0"  # Replace with your AMI

# Auto Scaling Configuration
asg_min_size         = 3
asg_max_size         = 9
asg_desired_capacity = 3

# RDS Configuration
db_engine            = "mysql"
db_engine_version    = "8.0"
db_instance_class    = "db.t3.micro"
db_name              = "myappdb"
db_username          = "admin"
db_password          = "YourSecurePassword123!"
db_allocated_storage = 20
```

3. **Initialize Terraform**:

```bash
terraform init
```

4. **Review the execution plan**:

```bash
terraform plan
```

5. **Apply the configuration**:

```bash
terraform apply
```

6. **Access your infrastructure**:

After successful deployment, Terraform will output the ALB DNS name and other important values.

## Configuration Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `ami_id` | AMI ID for EC2 instances | `"ami-0c55b159cbfafe1f0"` |
| `db_name` | Database name | `"myappdb"` |
| `db_username` | Database master username | `"admin"` |
| `db_password` | Database master password (sensitive) | `"SecurePass123!"` |

### Optional Variables (with defaults)

| Variable | Description | Default |
|----------|-------------|---------|
| `project_name` | Project name for resource naming | `"tilt"` |
| `app_name` | Application name for resource naming | `"sensor"` |
| `environment` | Environment name | `"lab"` |
| `created_by` | Creator name for tagging | `"Toan-Tran"` |
| `vpc_cidr` | VPC CIDR block | `"10.0.0.0/16"` |
| `availability_zones` | List of 3 AZs (empty for auto-select) | `[]` |
| `instance_type` | EC2 instance type | `"t3.micro"` |
| `asg_min_size` | Minimum ASG capacity | `3` |
| `asg_max_size` | Maximum ASG capacity | `9` |
| `asg_desired_capacity` | Desired ASG capacity | `3` |
| `alb_health_check_path` | Health check path | `"/"` |
| `alb_health_check_interval` | Health check interval (seconds) | `30` |
| `alb_health_check_timeout` | Health check timeout (seconds) | `5` |
| `alb_healthy_threshold` | Healthy threshold count | `2` |
| `alb_unhealthy_threshold` | Unhealthy threshold count | `2` |
| `db_engine` | Database engine | `"mysql"` |
| `db_engine_version` | Database engine version | `"8.0"` |
| `db_instance_class` | RDS instance class | `"db.t3.micro"` |
| `db_allocated_storage` | Storage size in GB | `20` |
| `db_backup_retention_period` | Backup retention days | `7` |
| `db_skip_final_snapshot` | Skip final snapshot on destroy | `true` |

## Outputs

After deployment, the following outputs are available:

### VPC Outputs
- `vpc_id` - VPC identifier
- `vpc_cidr_block` - VPC CIDR block
- `public_subnet_ids` - List of public subnet IDs
- `private_subnet_ids` - List of private subnet IDs
- `availability_zones` - List of availability zones used

### ALB Outputs
- `alb_id` - ALB identifier
- `alb_arn` - ALB ARN
- `alb_dns_name` - ALB DNS name for accessing the application
- `alb_zone_id` - ALB Route53 zone ID
- `alb_security_group_id` - ALB security group ID
- `target_group_arn` - Target group ARN

### ASG Outputs
- `asg_id` - Auto Scaling Group identifier
- `asg_name` - Auto Scaling Group name
- `asg_arn` - Auto Scaling Group ARN
- `launch_template_id` - Launch template ID
- `ec2_security_group_id` - EC2 security group ID

### RDS Outputs
- `rds_instance_id` - RDS instance identifier
- `rds_endpoint` - RDS connection endpoint (hostname:port)
- `rds_address` - RDS hostname
- `rds_port` - RDS port number
- `rds_arn` - RDS instance ARN
- `rds_security_group_id` - RDS security group ID
- `db_subnet_group_name` - RDS subnet group name

## File Structure

```
terraform/
├── versions.tf                # Terraform and provider version constraints
├── variables.tf               # Input variable definitions with validation
├── outputs.tf                 # Output values for all resources
├── main.tf                    # VPC module configuration with NAT gateways
├── alb.tf                     # Application Load Balancer, target group, and listener
├── asg.tf                     # Launch template, Auto Scaling Group, and EC2 security group
├── rds.tf                     # RDS instance, subnet group, and RDS security group
├── terraform.tfvars.example   # Example variable values
└── README.md                  # This documentation
```

## Resource Naming Convention

All resources follow the naming pattern: `[service]-[project]-[app]-[env]-[purpose]`

Examples:
- VPC: `vpc-tilt-sensor-lab-main`
- ALB: `alb-tilt-sensor-lab-web`
- ASG: `asg-tilt-sensor-lab-web`
- RDS: `rds-tilt-sensor-lab-db`

## Mandatory Tags

All resources include the following tags:
- **Project**: "KiroDemo"
- **Environment**: "Lab"
- **CreatedBy**: Value from `created_by` variable
- **ManagedBy**: "Terraform"

## Resources Created

### Network Resources (main.tf)
- **VPC Module**: terraform-aws-modules/vpc/aws (~> 5.0)
- **VPC**: 1x VPC with DNS support and hostnames enabled
- **Subnets**: 3x public subnets + 3x private subnets across 3 AZs (dynamically calculated)
- **Internet Gateway**: 1x IGW attached to VPC
- **Route Tables**: Public and private route tables with proper routing
- **Data Source**: AWS availability zones query

### Application Load Balancer (alb.tf)
- **ALB**: Internet-facing Application Load Balancer spanning all 3 public subnets
- **Target Group**: HTTP target group with configurable health checks
- **Listener**: HTTP listener on port 80 forwarding to target group
- **Security Group**: ALB security group allowing HTTP (80) and HTTPS (443) from internet

### Auto Scaling (asg.tf)
- **Launch Template**: EC2 launch template with user data for basic web server
- **Auto Scaling Group**: ASG with configurable capacity, attached to ALB target group
- **Security Group**: EC2 security group allowing HTTP from ALB security group only

### Database (rds.tf)
- **RDS Instance**: Multi-AZ database with configurable engine, encrypted storage
- **DB Subnet Group**: Subnet group spanning all 3 private subnets
- **Security Group**: RDS security group allowing database port from EC2 security group only

## Security

### Security Groups

The infrastructure implements a layered security approach with three security groups using security group references:

1. **ALB Security Group** (`sg-tilt-sensor-lab-alb`):
   - **Inbound**: HTTP (80) and HTTPS (443) from 0.0.0.0/0
   - **Outbound**: All traffic to 0.0.0.0/0

2. **EC2 Security Group** (`sg-tilt-sensor-lab-ec2`):
   - **Inbound**: HTTP (80) from ALB security group (security group reference)
   - **Outbound**: All traffic to 0.0.0.0/0

3. **RDS Security Group** (`sg-tilt-sensor-lab-rds`):
   - **Inbound**: Database port from EC2 security group (security group reference)
   - **Outbound**: None (not required for RDS)

### Network Architecture

- **Public Subnets**: Dynamically calculated CIDR blocks
  - Route to Internet Gateway for public internet access
  - Host ALB and EC2 instances with public IPs enabled
  - Distributed across 3 AZs
  
- **Private Subnets**: Dynamically calculated CIDR blocks
  - No direct internet access (isolated for database security)
  - Host RDS database instances
  - Distributed across 3 AZs

### Best Practices

- Store `terraform.tfvars` in a secure location (never commit to version control)
- Use AWS Secrets Manager or Parameter Store for sensitive values like `db_password`
- Enable MFA for AWS accounts
- Regularly update AMIs and apply security patches
- Review and audit security group rules periodically
- Set `db_skip_final_snapshot = false` for production environments

## High Availability

The infrastructure is designed to tolerate the failure of an entire Availability Zone:

- **Multi-AZ Distribution**: All resources span 3 AZs (dynamically selected)
- **ALB Health Checks**: Automatically routes traffic to healthy instances
- **Auto Scaling**: Maintains desired capacity across zones, automatically replaces failed instances
- **RDS Multi-AZ**: Automatic failover to standby replica in different AZ
- **NAT Gateways**: One per AZ for redundancy

## Cost Estimation

Approximate monthly costs (us-east-1 region):

- VPC and networking: Free
- ALB: ~$16/month
- EC2 instances (3x t3.micro): ~$9/month
- RDS (db.t3.micro Multi-AZ): ~$30/month
- Data transfer: Variable

**Total: ~$55/month** (excluding data transfer)

*Note: Costs vary by region and usage. Use AWS Cost Calculator for accurate estimates.*

## Supported Database Engines

The configuration supports the following database engines:
- MySQL (default port: 3306)
- PostgreSQL (port: 5432)
- MariaDB (port: 3306)
- Oracle SE2 (port: 1521)
- SQL Server Express (port: 1433)

The RDS security group automatically configures the correct port based on the selected engine.

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Warning**: This will permanently delete all resources. By default, `db_skip_final_snapshot = true`, which means no final snapshot will be taken. For production environments, set this to `false` to preserve data before destruction.

## Troubleshooting

### Common Issues

**Issue**: `terraform init` fails with module download error
- **Solution**: Ensure you have internet connectivity and can access registry.terraform.io

**Issue**: `terraform plan` fails with "Invalid CIDR block"
- **Solution**: Ensure `vpc_cidr` is a valid CIDR notation (e.g., "10.0.0.0/16")

**Issue**: `terraform apply` fails with "Insufficient capacity"
- **Solution**: Try a different instance type or region

**Issue**: `terraform apply` fails with "Not enough availability zones"
- **Solution**: The configuration requires at least 3 AZs. Choose a region with 3+ AZs

**Issue**: RDS creation fails with password requirements
- **Solution**: Ensure `db_password` is at least 8 characters with mixed case and numbers

**Issue**: Cannot connect to RDS from EC2
- **Solution**: Verify security group rules and ensure EC2 instances are in the correct subnets

## Required IAM Permissions

The AWS user/role running Terraform needs the following permissions:
- VPC: Create/modify/delete VPCs, subnets, route tables, internet gateways, NAT gateways
- EC2: Create/modify/delete security groups, launch templates, instances
- ELB: Create/modify/delete load balancers, target groups, listeners
- Auto Scaling: Create/modify/delete auto scaling groups
- RDS: Create/modify/delete DB instances, subnet groups
- IAM: PassRole (if using IAM roles for EC2 instances)

## Support

For issues or questions:
- Review AWS documentation: https://docs.aws.amazon.com/
- Review Terraform documentation: https://www.terraform.io/docs/
- Review terraform-aws-modules documentation: https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws

## License

This Terraform configuration is provided as-is for educational and production use.
