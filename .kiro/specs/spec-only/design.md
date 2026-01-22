# Design Document: Terraform 3-Tier AWS Architecture Generator

## Overview

This design describes a Terraform code generator that creates a production-ready, highly available 3-tier AWS architecture. The system generates Infrastructure-as-Code (IaC) that provisions:

1. **Network Layer**: VPC with public and private subnets across 3 Availability Zones
2. **Application Layer**: Auto Scaling Group of EC2 instances behind an Application Load Balancer
3. **Data Layer**: Multi-AZ RDS database instance in private subnets

The generated Terraform code follows AWS best practices for high availability, security, and maintainability. All resources are distributed across 3 Availability Zones to ensure the infrastructure can tolerate the failure of an entire zone.

## Architecture

### High-Level Architecture

```
Internet
    |
    v
[Internet Gateway]
    |
    v
[Application Load Balancer] (Public Subnets - 3 AZs)
    |
    v
[Auto Scaling Group] (Public Subnets - 3 AZs)
    |
    v
[RDS Multi-AZ] (Private Subnets - 3 AZs)
```

### Network Architecture

**VPC Structure:**
- 1 VPC with configurable CIDR block (default: 10.0.0.0/16)
- 3 Public Subnets (one per AZ) for internet-facing resources
- 3 Private Subnets (one per AZ) for database resources
- 1 Internet Gateway for public subnet internet access

**Subnet Allocation:**
- Public Subnets: 10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24
- Private Subnets: 10.0.11.0/24, 10.0.12.0/24, 10.0.13.0/24

**Routing:**
- Public route table: Routes 0.0.0.0/0 to Internet Gateway
- Private subnets: No internet access (isolated)

### Security Architecture

**Security Groups:**

1. **ALB Security Group:**
   - Ingress: 0.0.0.0/0 on port 80 (HTTP)
   - Ingress: 0.0.0.0/0 on port 443 (HTTPS)
   - Egress: EC2 security group on application port

2. **EC2 Security Group:**
   - Ingress: ALB security group on application port (e.g., 80)
   - Egress: 0.0.0.0/0 on all ports (for updates, external APIs)
   - Egress: RDS security group on database port

3. **RDS Security Group:**
   - Ingress: EC2 security group on database port (e.g., 3306 for MySQL)
   - Egress: None required

### High Availability Design

**Multi-AZ Distribution:**
- All resources span 3 Availability Zones
- ALB distributes traffic across all zones
- ASG maintains instance distribution across zones
- RDS Multi-AZ provides automatic failover

**Failure Scenarios:**
- Single AZ failure: ALB redirects traffic to healthy zones, ASG replaces instances
- Instance failure: ALB health checks detect failure, ASG launches replacement
- Database failure: RDS automatically fails over to standby in different AZ

## Components and Interfaces

### Terraform Module Structure

The generated Terraform code will be organized into the following files:

**main.tf:**
- VPC and networking resources
- Subnet definitions
- Internet Gateway and NAT Gateways
- Route tables and associations

**alb.tf:**
- Application Load Balancer
- Target Group
- Listener configuration
- ALB security group

**asg.tf:**
- Launch template
- Auto Scaling Group
- ASG policies
- EC2 security group

**rds.tf:**
- RDS subnet group
- RDS instance
- RDS security group

**variables.tf:**
- Input variables for configuration

**outputs.tf:**
- Output values for important resource attributes

**terraform.tfvars (example):**
- Example variable values

### Key Terraform Resources

**Networking:**
```hcl
resource "aws_vpc" "main"
resource "aws_subnet" "public" (count = 3)
resource "aws_subnet" "private" (count = 3)
resource "aws_internet_gateway" "main"
resource "aws_route_table" "public"
resource "aws_route_table" "private"
```

**Load Balancer:**
```hcl
resource "aws_lb" "main"
resource "aws_lb_target_group" "main"
resource "aws_lb_listener" "http"
resource "aws_security_group" "alb"
```

**Auto Scaling:**
```hcl
resource "aws_launch_template" "main"
resource "aws_autoscaling_group" "main"
resource "aws_security_group" "ec2"
```

**Database:**
```hcl
resource "aws_db_subnet_group" "main"
resource "aws_db_instance" "main"
resource "aws_security_group" "rds"
```

### Configuration Variables

**Required Variables:**
- `vpc_cidr`: VPC CIDR block (default: "10.0.0.0/16")
- `project_name`: Name prefix for all resources
- `environment`: Environment name (e.g., "production", "staging")

**EC2 Configuration:**
- `instance_type`: EC2 instance type (default: "t3.micro")
- `ami_id`: AMI ID for EC2 instances
- `min_size`: Minimum ASG capacity (default: 3)
- `max_size`: Maximum ASG capacity (default: 9)
- `desired_capacity`: Desired ASG capacity (default: 3)

**RDS Configuration:**
- `db_engine`: Database engine (default: "mysql")
- `db_engine_version`: Database engine version (default: "8.0")
- `db_instance_class`: RDS instance class (default: "db.t3.micro")
- `db_name`: Database name
- `db_username`: Master username
- `db_password`: Master password (sensitive)
- `db_allocated_storage`: Storage size in GB (default: 20)

**Availability Zones:**
- Dynamically queried using `data.aws_availability_zones.available`
- First 3 available zones used

### Output Values

**Network Outputs:**
- `vpc_id`: VPC identifier
- `public_subnet_ids`: List of public subnet IDs
- `private_subnet_ids`: List of private subnet IDs

**Application Outputs:**
- `alb_dns_name`: ALB DNS name for accessing the application
- `alb_arn`: ALB ARN
- `asg_name`: Auto Scaling Group name

**Database Outputs:**
- `rds_endpoint`: RDS connection endpoint
- `rds_address`: RDS hostname
- `rds_port`: RDS port number

## Data Models

### Terraform Variable Schema

```hcl
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
}

variable "min_size" {
  description = "Minimum number of EC2 instances"
  type        = number
  default     = 3
}

variable "max_size" {
  description = "Maximum number of EC2 instances"
  type        = number
  default     = 9
}

variable "desired_capacity" {
  description = "Desired number of EC2 instances"
  type        = number
  default     = 3
}

variable "db_engine" {
  description = "Database engine"
  type        = string
  default     = "mysql"
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

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_username" {
  description = "Database master username"
  type        = string
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}
```

### Resource Naming Convention

All resources follow the naming pattern: `{project_name}-{environment}-{resource_type}`

Examples:
- VPC: `myapp-production-vpc`
- Public Subnet: `myapp-production-public-subnet-1`
- ALB: `myapp-production-alb`
- ASG: `myapp-production-asg`
- RDS: `myapp-production-rds`

### Resource Tagging

All resources include these tags:
```hcl
tags = {
  Name        = "{resource_name}"
  Project     = var.project_name
  Environment = var.environment
  ManagedBy   = "Terraform"
}
```


## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### VPC and Networking Properties

**Property 1: VPC has configurable CIDR**
*For any* generated Terraform configuration, the VPC resource should reference a variable for its CIDR block, allowing users to configure the network address space.
**Validates: Requirements 1.1**

**Property 2: Subnet creation across AZs**
*For any* generated Terraform configuration, there should be exactly 3 public subnet resources and exactly 3 private subnet resources, each in a different Availability Zone.
**Validates: Requirements 1.2, 1.3**

**Property 3: Internet Gateway attachment**
*For any* generated Terraform configuration, an Internet Gateway resource should exist with a vpc_id attribute referencing the VPC.
**Validates: Requirements 1.4**

**Property 4: Public route to Internet Gateway**
*For any* generated Terraform configuration, the public route table should contain a route with destination 0.0.0.0/0 pointing to the Internet Gateway.
**Validates: Requirements 1.5**

**Property 5: Non-overlapping subnet CIDRs**
*For any* generated Terraform configuration, all subnet CIDR blocks should be non-overlapping and fall within the VPC CIDR range.
**Validates: Requirements 1.6**

### Load Balancer Properties

**Property 6: ALB in public subnets**
*For any* generated Terraform configuration, the Application Load Balancer resource should reference all 3 public subnet IDs.
**Validates: Requirements 2.1, 2.8**

**Property 7: ALB internet-facing configuration**
*For any* generated Terraform configuration, the ALB resource should have internal = false or scheme = "internet-facing".
**Validates: Requirements 2.2**

**Property 8: Target group exists**
*For any* generated Terraform configuration, a target group resource should exist with a reference to the VPC.
**Validates: Requirements 2.3**

**Property 9: Target group health checks**
*For any* generated Terraform configuration, the target group resource should include a health_check configuration block.
**Validates: Requirements 2.4**

**Property 10: ALB security group ingress ports**
*For any* generated Terraform configuration, the ALB security group should have ingress rules allowing traffic from 0.0.0.0/0 on ports 80 and 443.
**Validates: Requirements 2.5, 2.6**

**Property 11: ALB HTTP listener**
*For any* generated Terraform configuration, an ALB listener resource should exist for port 80 with a reference to the ALB and target group.
**Validates: Requirements 2.7**

### Auto Scaling Group Properties

**Property 12: Launch template with configurable instance type**
*For any* generated Terraform configuration, a launch template resource should exist with an instance_type attribute that references a variable.
**Validates: Requirements 3.1**

**Property 13: ASG uses launch template**
*For any* generated Terraform configuration, the Auto Scaling Group resource should reference the launch template.
**Validates: Requirements 3.2**

**Property 14: ASG distribution across AZs**
*For any* generated Terraform configuration, the ASG resource should reference all 3 public subnets, ensuring instance distribution across all Availability Zones.
**Validates: Requirements 3.3, 3.8**

**Property 15: ASG capacity configuration**
*For any* generated Terraform configuration, the ASG resource should have min_size, max_size, and desired_capacity attributes defined.
**Validates: Requirements 3.4**

**Property 16: ASG attached to target group**
*For any* generated Terraform configuration, the ASG resource should have a target_group_arns attribute referencing the ALB target group.
**Validates: Requirements 3.5**

**Property 17: EC2 security group allows ALB traffic**
*For any* generated Terraform configuration, the EC2 security group should have an ingress rule that references the ALB security group as the source.
**Validates: Requirements 3.6**

**Property 18: EC2 security group allows outbound internet**
*For any* generated Terraform configuration, the EC2 security group should have an egress rule allowing traffic to 0.0.0.0/0.
**Validates: Requirements 3.7**

### RDS Database Properties

**Property 19: RDS subnet group with private subnets**
*For any* generated Terraform configuration, an RDS subnet group resource should exist referencing all 3 private subnet IDs.
**Validates: Requirements 4.1**

**Property 20: RDS Multi-AZ enabled**
*For any* generated Terraform configuration, the RDS instance resource should have multi_az = true.
**Validates: Requirements 4.2**

**Property 21: RDS configurable engine**
*For any* generated Terraform configuration, the RDS instance should have an engine attribute that references a variable.
**Validates: Requirements 4.3**

**Property 22: RDS configurable instance class**
*For any* generated Terraform configuration, the RDS instance should have an instance_class attribute that references a variable.
**Validates: Requirements 4.4**

**Property 23: RDS security group allows EC2 traffic**
*For any* generated Terraform configuration, the RDS security group should have an ingress rule that references the EC2 security group as the source.
**Validates: Requirements 4.5**

**Property 24: RDS uses subnet group**
*For any* generated Terraform configuration, the RDS instance should have a db_subnet_group_name attribute referencing the RDS subnet group.
**Validates: Requirements 4.6**

**Property 25: RDS automated backups enabled**
*For any* generated Terraform configuration, the RDS instance should have backup_retention_period set to a value greater than 0.
**Validates: Requirements 4.7**

### Security Properties

**Property 26: Security groups have explicit rules**
*For any* generated Terraform configuration, all security group resources should have at least one ingress or egress rule explicitly defined.
**Validates: Requirements 5.1**

**Property 27: Security group traffic chain**
*For any* generated Terraform configuration, the security group chain should enforce: ALB allows internet traffic on ports 80/443, EC2 allows traffic only from ALB, and RDS allows traffic only from EC2.
**Validates: Requirements 5.2, 5.3, 5.4**

**Property 28: Internal security group references**
*For any* generated Terraform configuration, security group rules for internal traffic (EC2 to RDS, ALB to EC2) should use security_groups attribute instead of cidr_blocks.
**Validates: Requirements 5.5**

**Property 29: Security groups have descriptions**
*For any* generated Terraform configuration, all security group resources should have non-empty name and description attributes.
**Validates: Requirements 5.6**

### Code Quality Properties

**Property 30: Logical file organization**
*For any* generated Terraform configuration, ALB resources should be in alb.tf, ASG resources in asg.tf, RDS resources in rds.tf, and networking resources in main.tf.
**Validates: Requirements 6.1**

**Property 31: Variables for configuration**
*For any* generated Terraform configuration, a variables.tf file should exist with variable declarations for vpc_cidr, instance_type, db_engine, db_instance_class, and other configurable parameters.
**Validates: Requirements 6.2**

**Property 32: Output values defined**
*For any* generated Terraform configuration, an outputs.tf file should exist with output declarations for vpc_id, alb_dns_name, and rds_endpoint.
**Validates: Requirements 6.3**

**Property 33: Consistent naming convention**
*For any* generated Terraform configuration, all resource names should follow the pattern containing project_name and environment variables.
**Validates: Requirements 6.4**

**Property 34: Resources are tagged**
*For any* generated Terraform configuration, all taggable resources (VPC, subnets, ALB, ASG, RDS) should have a tags block with at least Name, Project, and Environment tags.
**Validates: Requirements 6.5**

**Property 35: Dynamic AZ data source**
*For any* generated Terraform configuration, a data source for aws_availability_zones should exist to dynamically query available zones.
**Validates: Requirements 6.6**

**Property 36: Valid HCL syntax**
*For any* generated Terraform configuration, running `terraform validate` should return no syntax errors.
**Validates: Requirements 6.7**

**Property 37: Terraform formatting compliance**
*For any* generated Terraform configuration, running `terraform fmt -check` should return no formatting violations.
**Validates: Requirements 6.8**

## Error Handling

### Terraform Validation Errors

**Invalid CIDR Blocks:**
- If VPC CIDR is invalid, Terraform will fail during plan phase
- Subnet CIDRs must be valid subsets of VPC CIDR
- Error message: "invalid CIDR address"

**Resource Dependencies:**
- Terraform automatically handles resource creation order through implicit dependencies
- Explicit depends_on used only when necessary (e.g., NAT Gateway depends on Internet Gateway)

**Missing Required Variables:**
- Variables without defaults must be provided via terraform.tfvars or command line
- Error message: "variable not set"

**AWS API Errors:**
- Insufficient permissions: Ensure IAM role/user has necessary permissions
- Resource limits: Check AWS service quotas (e.g., VPC limit, EIP limit)
- Availability Zone availability: Some instance types not available in all AZs

### Configuration Validation

**Capacity Values:**
- min_size must be ≤ desired_capacity ≤ max_size
- Terraform will validate this during plan phase

**Database Configuration:**
- db_password must meet AWS password requirements (8+ characters)
- db_engine_version must be compatible with db_engine

**Network Configuration:**
- Subnet CIDR blocks must not overlap
- Subnet CIDR blocks must be within VPC CIDR range
- Each subnet must be in a different Availability Zone

## Testing Strategy

### Dual Testing Approach

This infrastructure code will be validated using both unit tests and property-based tests:

**Unit Tests:**
- Verify specific configuration examples
- Test edge cases (e.g., minimum/maximum capacity values)
- Validate error conditions (e.g., invalid CIDR blocks)
- Test integration between components

**Property-Based Tests:**
- Verify universal properties across all generated configurations
- Test with randomized input values (CIDR blocks, instance types, etc.)
- Ensure correctness properties hold for all valid inputs
- Comprehensive coverage through randomization

### Property-Based Testing Implementation

**Testing Framework:**
- Use Terratest (Go) for infrastructure testing
- Use QuickCheck-style property testing library for Go
- Minimum 100 iterations per property test

**Test Configuration:**
Each property test will:
1. Generate random valid input values
2. Run the Terraform generator
3. Parse the generated Terraform code
4. Verify the property holds
5. Tag with: **Feature: spec-only, Property {N}: {property_text}**

**Example Property Test Structure:**
```go
func TestProperty1_VPCHasConfigurableCIDR(t *testing.T) {
    // Feature: spec-only, Property 1: VPC has configurable CIDR
    
    property := gopter.NewProperties(nil)
    property.Property("VPC resource references CIDR variable", 
        prop.ForAll(
            func(cidr string) bool {
                // Generate Terraform code
                code := generateTerraform(cidr)
                
                // Parse and verify VPC has variable reference
                return vpcHasVariableCIDR(code)
            },
            gen.RegexMatch("^10\\.\\d+\\.\\d+\\.\\d+/\\d+$"),
        ))
    
    properties.TestingRun(t, gopter.ConsoleReporter(false))
}
```

### Unit Testing Strategy

**File Organization Tests:**
- Verify resources appear in correct files
- Check file naming conventions

**Resource Configuration Tests:**
- Test specific valid configurations
- Test boundary conditions (min/max values)
- Test invalid configurations (should fail validation)

**Integration Tests:**
- Verify resource references are correct
- Test security group chains
- Validate subnet associations

### Terraform Validation

**Static Analysis:**
- Run `terraform validate` on generated code
- Run `terraform fmt -check` for style compliance
- Use tflint for additional linting

**Plan Testing:**
- Run `terraform plan` to verify no errors
- Check plan output for expected resource counts
- Verify resource attributes in plan

**Cost Estimation:**
- Use Infracost to estimate monthly costs
- Verify costs are within expected ranges for test configurations

### Test Execution

**Pre-commit Hooks:**
- Run terraform fmt on all .tf files
- Run terraform validate
- Run unit tests

**CI/CD Pipeline:**
- Run all unit tests
- Run all property-based tests (100 iterations each)
- Run terraform validate and plan
- Generate cost estimates
- Require all tests to pass before merge

### Coverage Goals

- 100% of correctness properties implemented as property tests
- All edge cases covered by unit tests
- All error conditions tested
- Integration between all components validated
