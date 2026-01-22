# Terraform 3-Tier AWS Architecture

This Terraform configuration creates a production-ready, highly available 3-tier AWS architecture with resources distributed across 3 Availability Zones.

## Architecture Overview

The infrastructure consists of:

1. **Network Layer**: VPC (default 10.0.0.0/16) with 3 public subnets and 3 private subnets across 3 AZs
2. **Application Layer**: Auto Scaling Group (3-9 instances) behind an Application Load Balancer
3. **Data Layer**: Multi-AZ RDS MySQL database instance in private subnets

```
Internet
    |
    v
[Internet Gateway]
    |
    v
[Application Load Balancer] (Public Subnets: 10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24)
    |
    v
[Auto Scaling Group - EC2 Instances] (Public Subnets - 3 AZs)
    |
    v
[RDS Multi-AZ Database] (Private Subnets: 10.0.11.0/24, 10.0.12.0/24, 10.0.13.0/24)
```

## Estimated Monthly Cost

Based on Infracost analysis (us-east-1 region):

- **RDS Database Instance** (db.t3.micro Multi-AZ): $29.42/month
- **Auto Scaling Group** (3x t3.micro instances): $22.78/month
- **Application Load Balancer**: $16.43/month
- **VPC and Networking**: Free

**Total: ~$68.62/month** (excluding data transfer costs)

*Note: Costs vary by region, usage patterns, and data transfer. Use AWS Cost Calculator or Infracost for accurate estimates.*

## Features

- **High Availability**: All resources span 3 Availability Zones
- **Auto Scaling**: EC2 instances scale from 3 to 9 instances based on demand (configurable)
- **Load Balancing**: Application Load Balancer with HTTP listener and health checks
- **Database Redundancy**: Multi-AZ RDS with 7-day backup retention
- **Security**: Layered security groups with least privilege access using security group references
- **Network Isolation**: Public subnets for web tier, private subnets for database tier
- **Dynamic AZ Selection**: Automatically queries available AZs in the region
- **Best Practices**: Follows AWS and Terraform best practices with proper tagging

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate credentials
- An AWS account with necessary permissions
- At least 3 Availability Zones available in your target AWS region

**Note**: The current configuration uses AWS Provider version 6.28.0 (as shown in `.terraform.lock.hcl`). For production use, consider creating a `versions.tf` file to explicitly pin provider versions:

```hcl
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
```

## Subnet CIDR Calculation

The configuration automatically calculates subnet CIDR blocks from the VPC CIDR using Terraform's `cidrsubnet` function:

- **Public Subnets**: `cidrsubnet(var.vpc_cidr, 8, count.index + 1)`
  - For VPC 10.0.0.0/16: Creates 10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24
  
- **Private Subnets**: `cidrsubnet(var.vpc_cidr, 8, count.index + 11)`
  - For VPC 10.0.0.0/16: Creates 10.0.11.0/24, 10.0.12.0/24, 10.0.13.0/24

This ensures non-overlapping address ranges within the VPC and allows for easy customization of the VPC CIDR block.

## Dynamic Availability Zone Selection

The configuration uses a data source to dynamically query available AZs in your region:

```hcl
data "aws_availability_zones" "available" {
  state = "available"
}
```

Subnets are then distributed across the first 3 available AZs: `data.aws_availability_zones.available.names[count.index]`

This approach ensures the configuration works across different AWS regions without hardcoding AZ names.

## Quick Start

1. **Clone or copy the Terraform files to your project directory**

2. **Create a `terraform.tfvars` file** (use `terraform.tfvars.example` as a template):

```hcl
project_name = "myapp"
environment  = "production"
vpc_cidr     = "10.0.0.0/16"
instance_type = "t3.micro"
ami_id        = "ami-0c55b159cbfafe1f0"  # Replace with your AMI
min_size         = 3
max_size         = 9
desired_capacity = 3
db_engine            = "mysql"
db_engine_version    = "8.0"
db_instance_class    = "db.t3.micro"
db_name              = "myappdb"
db_username          = "admin"
db_password          = "ChangeMe123!"  # Use a secure password
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
| `project_name` | Project name for resource naming | `"myapp"` |
| `environment` | Environment name | `"production"` |
| `ami_id` | AMI ID for EC2 instances | `"ami-0c55b159cbfafe1f0"` |
| `db_name` | Database name | `"myappdb"` |
| `db_username` | Database master username | `"admin"` |
| `db_password` | Database master password (sensitive) | `"SecurePass123!"` |

### Optional Variables (with defaults)

| Variable | Description | Default |
|----------|-------------|---------|
| `vpc_cidr` | VPC CIDR block | `"10.0.0.0/16"` |
| `instance_type` | EC2 instance type | `"t3.micro"` |
| `min_size` | Minimum ASG capacity | `3` |
| `max_size` | Maximum ASG capacity | `9` |
| `desired_capacity` | Desired ASG capacity | `3` |
| `db_engine` | Database engine | `"mysql"` |
| `db_engine_version` | Database engine version | `"8.0"` |
| `db_instance_class` | RDS instance class | `"db.t3.micro"` |
| `db_allocated_storage` | Storage size in GB | `20` |

## Outputs

After deployment, the following outputs are available:

| Output | Description |
|--------|-------------|
| `vpc_id` | VPC identifier |
| `public_subnet_ids` | List of public subnet IDs |
| `private_subnet_ids` | List of private subnet IDs |
| `alb_dns_name` | ALB DNS name for accessing the application |
| `alb_arn` | ALB ARN |
| `asg_name` | Auto Scaling Group name |
| `rds_endpoint` | RDS connection endpoint |
| `rds_address` | RDS hostname |
| `rds_port` | RDS port number |

## File Structure

```
terraform/
├── main.tf                    # VPC, subnets, IGW, route tables, and AZ data source
├── alb.tf                     # Application Load Balancer, target group, listener, and ALB security group
├── asg.tf                     # Launch template, Auto Scaling Group, and EC2 security group
├── rds.tf                     # RDS instance, subnet group, and RDS security group
├── variables.tf               # Input variable definitions
├── outputs.tf                 # Output values for VPC, ALB, ASG, and RDS
├── terraform.tfvars.example   # Example variable values
└── README.md                  # This documentation
```

## Resource Naming and Tagging

### Naming Convention

All resources follow a consistent naming pattern:
```
${project_name}-${environment}-${resource_type}
```

Examples:
- VPC: `myapp-production-vpc`
- ALB: `myapp-production-alb`
- ASG: `myapp-production-asg`
- RDS: `myapp-production-rds`

### Mandatory Tags

All resources include the following tags:
- **Name**: Resource-specific name following the naming convention
- **Project**: Value from `project_name` variable
- **Environment**: Value from `environment` variable
- **ManagedBy**: "Terraform"

These tags enable cost tracking, resource organization, and automated management.

## Resources Created

### Network Resources (main.tf)
- **Data Source**: AWS availability zones query (dynamically selects first 3 available AZs)
- **VPC**: 1x VPC with DNS support and hostnames enabled
- **Subnets**: 3x public subnets (10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24) + 3x private subnets (10.0.11.0/24, 10.0.12.0/24, 10.0.13.0/24) across 3 AZs
- **Internet Gateway**: 1x IGW attached to VPC for public internet access
- **Route Tables**: 1x public route table (routes 0.0.0.0/0 to IGW) + 1x private route table (no internet route)
- **Route Table Associations**: 6x associations (3 public + 3 private)

### Application Load Balancer (alb.tf)
- **ALB**: 1x internet-facing Application Load Balancer spanning all 3 public subnets
- **Target Group**: 1x target group with HTTP health checks (path: /, interval: 30s, timeout: 5s, healthy threshold: 2, unhealthy threshold: 2)
- **Listener**: 1x HTTP listener on port 80 forwarding to target group
- **Security Group**: ALB security group allowing HTTP (80) and HTTPS (443) from internet (0.0.0.0/0)

### Auto Scaling (asg.tf)
- **Launch Template**: EC2 launch template with configurable AMI and instance type, public IP enabled
- **Auto Scaling Group**: ASG with configurable capacity (default: min=3, max=9, desired=3), attached to ALB target group
- **Security Group**: EC2 security group allowing HTTP (80) from ALB security group only (using security group reference)

### Database (rds.tf)
- **RDS Instance**: Multi-AZ database with configurable engine (default: MySQL 8.0), 7-day backup retention, skip final snapshot enabled
- **DB Subnet Group**: Subnet group spanning all 3 private subnets
- **Security Group**: RDS security group allowing database port (3306 for MySQL) from EC2 security group only (using security group reference)

## Security

### Security Groups

The infrastructure implements a layered security approach with three security groups using security group references (not CIDR blocks) for internal traffic:

1. **ALB Security Group** (`${project_name}-${environment}-alb-sg`):
   - **Inbound**: HTTP (80) and HTTPS (443) from 0.0.0.0/0
   - **Outbound**: All traffic to 0.0.0.0/0

2. **EC2 Security Group** (`${project_name}-${environment}-ec2-sg`):
   - **Inbound**: HTTP (80) from ALB security group (security group reference)
   - **Outbound**: All traffic to 0.0.0.0/0

3. **RDS Security Group** (`${project_name}-${environment}-rds-sg`):
   - **Inbound**: Database port (3306 for MySQL) from EC2 security group (security group reference)
   - **Outbound**: None (not required for RDS)

### Network Architecture

- **Public Subnets**: Dynamically calculated CIDR blocks (10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24 for default VPC CIDR)
  - Route to Internet Gateway for public internet access
  - Host ALB and EC2 instances with public IPs enabled
  - Distributed across first 3 available AZs in the region
  
- **Private Subnets**: Dynamically calculated CIDR blocks (10.0.11.0/24, 10.0.12.0/24, 10.0.13.0/24 for default VPC CIDR)
  - No direct internet access (no NAT Gateway configured)
  - Host RDS database instances
  - Distributed across first 3 available AZs in the region

### Best Practices

- Store `terraform.tfvars` in a secure location (never commit to version control)
- Use AWS Secrets Manager or Parameter Store for sensitive values like `db_password`
- Enable MFA for AWS accounts
- Regularly update AMIs and apply security patches
- Review and audit security group rules periodically
- The configuration uses `skip_final_snapshot = true` for RDS - change to `false` for production with a final snapshot identifier

## High Availability

The infrastructure is designed to tolerate the failure of an entire Availability Zone:

- **Multi-AZ Distribution**: All resources span 3 AZs (dynamically selected from available AZs)
- **ALB Health Checks**: Automatically routes traffic to healthy instances (healthy threshold: 2, unhealthy threshold: 2, interval: 30s)
- **Auto Scaling**: Maintains desired capacity across zones, automatically replaces failed instances
- **RDS Multi-AZ**: Automatic failover to standby replica in different AZ with 7-day backup retention

## Cost Breakdown

Based on Infracost analysis for the default configuration (us-east-1 region):

| Resource | Monthly Cost |
|----------|--------------|
| RDS Database Instance (db.t3.micro Multi-AZ) | $29.42 |
| Auto Scaling Group (3x t3.micro instances) | $22.78 |
| Application Load Balancer | $16.43 |
| VPC and Networking | Free |
| **Total** | **$68.62** |

*Note: This estimate excludes data transfer costs, which vary based on actual traffic. Costs may differ by region and usage patterns. For accurate cost estimation, use the Infracost tool or AWS Cost Calculator.*

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Warning**: This will permanently delete all resources. The configuration has `skip_final_snapshot = true` for RDS, which means no final snapshot will be taken. For production environments, change this setting to preserve data before destruction.

## Important Configuration Notes

### RDS Configuration
- **Multi-AZ**: Enabled by default for high availability
- **Backup Retention**: 7 days
- **Skip Final Snapshot**: Set to `true` (change to `false` for production)
- **Port**: 3306 (MySQL default) - update security group if using different database engine

### Launch Template
- **Version**: ASG uses `$Latest` version automatically
- **Public IP**: Enabled for instances in public subnets
- **Security Group**: Attached via network interface configuration

### Auto Scaling Group
- **Distribution**: Even distribution across all 3 AZs
- **Target Group**: Automatically attached to ALB target group
- **Tags**: Propagated to launched instances (except ASG name tag)

## Troubleshooting

### Common Issues

**Issue**: `terraform plan` fails with "Invalid CIDR block"
- **Solution**: Ensure `vpc_cidr` is a valid CIDR notation (e.g., "10.0.0.0/16")

**Issue**: `terraform apply` fails with "Insufficient capacity"
- **Solution**: Try a different instance type or region

**Issue**: `terraform apply` fails with "Not enough availability zones"
- **Solution**: The configuration requires at least 3 AZs. Choose a region with 3+ AZs (most major regions support this)

**Issue**: RDS creation fails with password requirements
- **Solution**: Ensure `db_password` is at least 8 characters with mixed case and numbers

**Issue**: Cannot connect to RDS from EC2
- **Solution**: Verify security group rules and ensure EC2 instances are in the correct subnets. Check that the RDS security group allows traffic from the EC2 security group.

**Issue**: Launch template version error
- **Solution**: The ASG uses `$Latest` version of the launch template. If you modify the launch template, the ASG will automatically use the new version.

**Issue**: ALB health checks failing
- **Solution**: Ensure your application is listening on port 80 and responding to HTTP requests at the root path `/`. Adjust health check settings in `alb.tf` if needed.

## Customization

### Using Different Database Engines

To use PostgreSQL instead of MySQL, update your `terraform.tfvars`:

```hcl
db_engine         = "postgres"
db_engine_version = "14.7"
```

**Important**: You must also update the RDS security group port in `rds.tf` from 3306 to 5432:

```hcl
ingress {
  description     = "PostgreSQL from EC2"
  from_port       = 5432
  to_port         = 5432
  protocol        = "tcp"
  security_groups = [aws_security_group.ec2.id]
}
```

### Adding NAT Gateways

To enable private subnet internet access (for updates, external APIs), you need to:

1. Add Elastic IP resources for each NAT Gateway to `main.tf`:
```hcl
resource "aws_eip" "nat" {
  count  = 3
  domain = "vpc"
  tags = {
    Name        = "${var.project_name}-${var.environment}-nat-eip-${count.index + 1}"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
```

2. Add NAT Gateway resources to `main.tf`:
```hcl
resource "aws_nat_gateway" "main" {
  count         = 3
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags = {
    Name        = "${var.project_name}-${var.environment}-nat-${count.index + 1}"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
```

3. Update private route table to route through NAT Gateway (replace existing `aws_route_table.private` resource):
```hcl
resource "aws_route_table" "private" {
  count  = 3
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-private-rt-${count.index + 1}"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
```

4. Update private route table associations:
```hcl
resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
```

**Note**: NAT Gateways add approximately $32/month per AZ ($96/month total for 3 AZs) plus data transfer costs.

## Support

For issues or questions:
- Review AWS documentation: https://docs.aws.amazon.com/
- Review Terraform documentation: https://www.terraform.io/docs/

## License

This Terraform configuration is provided as-is for educational and production use.
