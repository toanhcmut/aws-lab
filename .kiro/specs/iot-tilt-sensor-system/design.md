# Design Document: IoT Tilt Sensor Monitoring System

## 1. Overview

This document provides the technical design for an IoT Tilt Sensor Monitoring System on AWS. The system implements a scheduled batch processing architecture that collects sensor data every 5 minutes, processes it through a multi-stage pipeline, and serves it via a web portal. The infrastructure emphasizes cost optimization, security, and scalability using AWS managed services orchestrated via Terraform.

### 1.1 Design Principles

- **Batch Processing Over Streaming**: Use scheduled Lambda triggers (every 5 minutes) to pull data from the message broker, optimizing compute costs
- **Message Ordering**: Employ SQS FIFO queues to ensure critical messages (alarms) are processed before normal status updates
- **Decoupling**: Use SQS queues as buffers between processing stages to prevent database throttling
- **Security by Design**: Implement least-privilege IAM policies, network segmentation, and WAF protection
- **Infrastructure as Code**: Modular Terraform design for maintainability and reusability

## 2. System Architecture

![System Architecture](./generated-diagrams/iot_tilt_sensor_architecture.png.png)

### 2.1 High-Level Architecture

The system consists of five primary layers:

1. **Ingestion Layer**: IoT devices → NLB → ECS Message Broker
2. **Processing Layer**: Scheduled Lambda pipeline with SQS queues
3. **Storage Layer**: Aurora PostgreSQL and ElastiCache Redis
4. **Application Layer**: EC2-hosted Portal API with ALB
5. **Security Layer**: CloudFront, WAF, IAM, and Security Groups


## 3. Detailed Component Design

### 3.1 Network Infrastructure

**Component**: VPC with Multi-AZ Architecture

**Design Decisions**:
- VPC CIDR: Configurable (e.g., 10.0.0.0/16)
- 2 Availability Zones for high availability
- Public subnets (10.0.1.0/24, 10.0.2.0/24) for load balancers
- Private subnets (10.0.10.0/24, 10.0.11.0/24) for compute and storage
- Internet Gateway for public subnet internet access
- NAT Gateway (optional) for private subnet outbound access

**Terraform Module**: `vpc`

**Resources**:
- `aws_vpc.main`
- `aws_subnet.public[2]`
- `aws_subnet.private[2]`
- `aws_internet_gateway.main`
- `aws_route_table.public`
- `aws_route_table.private`

**Naming Convention**:
- VPC: `vpc-tilt-sensor-lab`
- Subnets: `subnet-tilt-sensor-lab-public-az1`, `subnet-tilt-sensor-lab-private-az1`
- IGW: `igw-tilt-sensor-lab`

### 3.2 IoT Data Ingestion Layer

#### 3.2.1 Network Load Balancer

**Purpose**: Accept TCP connections from IoT devices and forward to ECS message broker

**Design Decisions**:
- Deployed in public subnets across 2 AZs
- TCP listener on configurable port (e.g., 1883 for MQTT)
- Target type: IP (for Fargate tasks)
- Health checks on broker endpoint

**Terraform Module**: `nlb`

**Resources**:
- `aws_lb.iot_nlb` (type: network)
- `aws_lb_target_group.ecs_broker`
- `aws_lb_listener.tcp`

**Naming Convention**:
- NLB: `nlb-tilt-sensor-lab-iot`
- Target Group: `tg-tilt-sensor-lab-ecs-broker`


#### 3.2.2 ECS Message Broker (Fargate)

**Purpose**: Act as MQTT broker to buffer IoT device connections and messages

**Design Decisions**:
- ECS Fargate for serverless container management
- Deployed in private subnets
- Container image: Eclipse Mosquitto or AWS IoT Core compatible broker
- Persistent storage via EFS (optional) for message retention
- Auto-scaling based on CPU/memory utilization

**Terraform Module**: `ecs`

**Resources**:
- `aws_ecs_cluster.main`
- `aws_ecs_task_definition.message_broker`
- `aws_ecs_service.message_broker`
- `aws_security_group.ecs_broker`

**Configuration**:
```hcl
task_cpu    = 512
task_memory = 1024
desired_count = 2
```

**Naming Convention**:
- Cluster: `ecs-tilt-sensor-lab`
- Service: `ecs-service-tilt-sensor-lab-broker`
- Task Definition: `ecs-task-tilt-sensor-lab-broker`

**Security Group Rules**:
- Ingress: TCP port 1883 from NLB
- Ingress: TCP port 8883 (TLS) from NLB
- Egress: All traffic (for pulling container images)

### 3.3 Scheduled Processing Pipeline

#### 3.3.1 EventBridge Ingestion Trigger

**Purpose**: Trigger Lambda_Parsing function every 5 minutes

**Design Decisions**:
- Schedule expression: `rate(5 minutes)`
- Target: Lambda_Parsing function
- Retry policy: 2 retries with exponential backoff

**Terraform Module**: `eventbridge`

**Resources**:
- `aws_cloudwatch_event_rule.ingestion_trigger`
- `aws_cloudwatch_event_target.lambda_parsing`
- `aws_lambda_permission.allow_eventbridge`

**Naming Convention**:
- Rule: `eventbridge-tilt-sensor-lab-ingestion`


#### 3.3.2 Lambda_Parsing Function

**Purpose**: Pull messages from ECS broker, parse MQTT data to JSON

**Design Decisions**:
- Runtime: Python 3.11 or Node.js 18
- Memory: 512 MB
- Timeout: 60 seconds
- VPC-enabled to access ECS broker in private subnet
- Environment variables: BROKER_ENDPOINT, MQTT_TOPIC

**Terraform Module**: `lambda`

**Resources**:
- `aws_lambda_function.parsing`
- `aws_iam_role.lambda_parsing`
- `aws_iam_policy.lambda_parsing`
- `aws_security_group.lambda_parsing`

**IAM Permissions**:
- `sqs:SendMessage` on sqs-fifo-distributing
- `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents`
- `ec2:CreateNetworkInterface`, `ec2:DescribeNetworkInterfaces`, `ec2:DeleteNetworkInterface` (for VPC)

**Naming Convention**:
- Function: `lambda-tilt-sensor-lab-parsing`
- Role: `iam-role-tilt-sensor-lab-lambda-parsing`

**Processing Logic**:
1. Connect to ECS broker as MQTT client
2. Subscribe to configured topics
3. Pull retained/buffered messages
4. Parse raw MQTT payload to JSON format:
```json
{
  "device_id": "sensor-001",
  "timestamp": "2026-01-18T10:30:00Z",
  "tilt_angle": 15.5,
  "status": "normal",
  "battery_level": 85
}
```
5. Send parsed messages to SQS FIFO queue


#### 3.3.3 SQS FIFO Queue (sqs-fifo-distributing)

**Purpose**: Ensure strict message ordering (alarms before normal status)

**Design Decisions**:
- FIFO queue for ordering guarantees
- Message group ID: device_id
- Content-based deduplication enabled
- Visibility timeout: 90 seconds
- Message retention: 4 days

**Terraform Module**: `sqs`

**Resources**:
- `aws_sqs_queue.fifo_distributing`

**Naming Convention**:
- Queue: `sqs-fifo-tilt-sensor-lab-distributing.fifo`

**Configuration**:
```hcl
fifo_queue                  = true
content_based_deduplication = true
visibility_timeout_seconds  = 90
message_retention_seconds   = 345600
```

#### 3.3.4 Lambda_Distributing Function

**Purpose**: Route messages based on business logic

**Design Decisions**:
- Runtime: Python 3.11
- Memory: 256 MB
- Timeout: 30 seconds
- Batch size: 10 messages
- Event source: sqs-fifo-distributing

**Terraform Module**: `lambda`

**Resources**:
- `aws_lambda_function.distributing`
- `aws_lambda_event_source_mapping.sqs_fifo_trigger`
- `aws_iam_role.lambda_distributing`

**IAM Permissions**:
- `sqs:ReceiveMessage`, `sqs:DeleteMessage`, `sqs:GetQueueAttributes` on sqs-fifo-distributing
- `sqs:SendMessage` on sqs-db1
- CloudWatch Logs permissions

**Naming Convention**:
- Function: `lambda-tilt-sensor-lab-distributing`

**Routing Logic**:
- All messages → sqs-db1 (for database persistence)
- Future: Route to additional queues based on message type


#### 3.3.5 SQS Standard Queue (sqs-db1)

**Purpose**: Buffer messages before database writes to prevent throttling

**Design Decisions**:
- Standard queue (ordering not critical at this stage)
- Visibility timeout: 120 seconds
- Message retention: 4 days
- Dead letter queue configured for failed messages

**Terraform Module**: `sqs`

**Resources**:
- `aws_sqs_queue.db1`
- `aws_sqs_queue.db1_dlq` (dead letter queue)

**Naming Convention**:
- Queue: `sqs-tilt-sensor-lab-db1`
- DLQ: `sqs-tilt-sensor-lab-db1-dlq`

#### 3.3.6 Lambda_DB1 Function

**Purpose**: Persist messages to Aurora PostgreSQL

**Design Decisions**:
- Runtime: Python 3.11
- Memory: 512 MB
- Timeout: 120 seconds
- Batch size: 25 messages
- VPC-enabled to access Aurora in private subnet
- Connection pooling for database efficiency

**Terraform Module**: `lambda`

**Resources**:
- `aws_lambda_function.db1`
- `aws_lambda_event_source_mapping.sqs_db1_trigger`
- `aws_iam_role.lambda_db1`
- `aws_security_group.lambda_db1`

**IAM Permissions**:
- `sqs:ReceiveMessage`, `sqs:DeleteMessage`, `sqs:GetQueueAttributes` on sqs-db1
- `rds-db:connect` on Aurora cluster
- CloudWatch Logs permissions
- VPC networking permissions

**Naming Convention**:
- Function: `lambda-tilt-sensor-lab-db1`

**Database Operations**:
- Insert sensor readings into `sensor_data` table
- Update device status in `device_status` table
- Handle duplicate detection via unique constraints


### 3.4 Storage Layer

#### 3.4.1 Aurora PostgreSQL Cluster

**Purpose**: Primary persistent storage for sensor data

**Design Decisions**:
- Aurora PostgreSQL Serverless v2 for auto-scaling
- Multi-AZ deployment for high availability
- Deployed in private subnets
- Automated backups with 7-day retention
- Encryption at rest using AWS KMS

**Terraform Module**: `rds`

**Resources**:
- `aws_rds_cluster.aurora`
- `aws_rds_cluster_instance.aurora[2]`
- `aws_db_subnet_group.aurora`
- `aws_security_group.aurora`

**Configuration**:
```hcl
engine         = "aurora-postgresql"
engine_mode    = "provisioned"
engine_version = "15.4"
instance_class = "db.serverless"
min_capacity   = 0.5
max_capacity   = 2
```

**Naming Convention**:
- Cluster: `rds-tilt-sensor-lab-aurora`
- Instances: `rds-tilt-sensor-lab-aurora-1`, `rds-tilt-sensor-lab-aurora-2`
- Subnet Group: `rds-subnet-tilt-sensor-lab`

**Security Group Rules**:
- Ingress: PostgreSQL (5432) from Lambda_DB1, EC2 Portal API, Lambda_Sync

**Database Schema**:
```sql
CREATE TABLE sensor_data (
    id SERIAL PRIMARY KEY,
    device_id VARCHAR(50) NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    tilt_angle DECIMAL(5,2),
    status VARCHAR(20),
    battery_level INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(device_id, timestamp)
);

CREATE TABLE device_status (
    device_id VARCHAR(50) PRIMARY KEY,
    last_seen TIMESTAMPTZ,
    current_status VARCHAR(20),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_sensor_data_device_timestamp ON sensor_data(device_id, timestamp DESC);
CREATE INDEX idx_sensor_data_status ON sensor_data(status);
```


#### 3.4.2 ElastiCache Redis Cluster

**Purpose**: Application caching layer for fast data retrieval

**Design Decisions**:
- Redis 7.0 cluster mode disabled
- Multi-AZ with automatic failover
- Deployed in private subnets
- Node type: cache.t3.micro (adjustable)

**Terraform Module**: `elasticache`

**Resources**:
- `aws_elasticache_replication_group.redis`
- `aws_elasticache_subnet_group.redis`
- `aws_security_group.redis`

**Configuration**:
```hcl
engine               = "redis"
engine_version       = "7.0"
node_type            = "cache.t3.micro"
num_cache_nodes      = 2
automatic_failover   = true
```

**Naming Convention**:
- Replication Group: `redis-tilt-sensor-lab`
- Subnet Group: `redis-subnet-tilt-sensor-lab`

**Security Group Rules**:
- Ingress: Redis (6379) from EC2 Portal API, Lambda_Sync

**Cached Data**:
- Recent device status (TTL: 5 minutes)
- Aggregated statistics (TTL: 10 minutes)
- User session data (TTL: 30 minutes)

### 3.5 Application Layer

#### 3.5.1 EC2 Portal API

**Purpose**: Backend API service for web portal

**Design Decisions**:
- EC2 instances in private subnets
- Auto Scaling Group with 2-4 instances
- Instance type: t3.medium
- Application: Node.js/Python REST API
- Connection to Aurora and Redis

**Terraform Module**: `ec2`

**Resources**:
- `aws_launch_template.portal_api`
- `aws_autoscaling_group.portal_api`
- `aws_security_group.portal_api`

**Naming Convention**:
- Launch Template: `lt-tilt-sensor-lab-portal`
- ASG: `asg-tilt-sensor-lab-portal`

**Security Group Rules**:
- Ingress: HTTP (80) from ALB
- Egress: PostgreSQL (5432) to Aurora
- Egress: Redis (6379) to ElastiCache
- Egress: HTTPS (443) for external APIs


#### 3.5.2 Application Load Balancer

**Purpose**: Distribute traffic to EC2 Portal API instances

**Design Decisions**:
- Deployed in public subnets
- HTTPS listener with SSL/TLS certificate
- Health checks on /health endpoint
- Sticky sessions enabled

**Terraform Module**: `alb`

**Resources**:
- `aws_lb.portal_alb`
- `aws_lb_target_group.portal_api`
- `aws_lb_listener.https`
- `aws_lb_listener.http_redirect`

**Naming Convention**:
- ALB: `alb-tilt-sensor-lab-portal`
- Target Group: `tg-tilt-sensor-lab-portal`

**Configuration**:
```hcl
load_balancer_type = "application"
enable_http2       = true
idle_timeout       = 60
```

**Security Group Rules**:
- Ingress: HTTPS (443) from CloudFront
- Ingress: HTTP (80) from CloudFront (redirect to HTTPS)
- Egress: HTTP (80) to EC2 instances

### 3.6 Command and Control Layer

#### 3.6.1 Command SQS FIFO Queues

**Purpose**: Queue commands for IoT devices

**Design Decisions**:
- Two separate FIFO queues for MQTT and LoRaWAN protocols
- Message group ID: device_id
- Content-based deduplication enabled

**Terraform Module**: `sqs`

**Resources**:
- `aws_sqs_queue.mqtt_command`
- `aws_sqs_queue.lorawan_command`

**Naming Convention**:
- MQTT Queue: `sqs-fifo-tilt-sensor-lab-mqtt-command.fifo`
- LoRaWAN Queue: `sqs-fifo-tilt-sensor-lab-lorawan-command.fifo`


#### 3.6.2 Command Handler Lambda Functions

**Purpose**: Process commands and forward to message broker

**Design Decisions**:
- Two Lambda functions (mqtt-command-handler, lorawan-command-handler)
- Runtime: Python 3.11
- Memory: 256 MB
- Timeout: 30 seconds
- VPC-enabled to access ECS broker

**Terraform Module**: `lambda`

**Resources**:
- `aws_lambda_function.mqtt_command_handler`
- `aws_lambda_function.lorawan_command_handler`
- `aws_lambda_event_source_mapping.mqtt_command_trigger`
- `aws_lambda_event_source_mapping.lorawan_command_trigger`

**Naming Convention**:
- MQTT Handler: `lambda-tilt-sensor-lab-mqtt-cmd-handler`
- LoRaWAN Handler: `lambda-tilt-sensor-lab-lorawan-cmd-handler`

**IAM Permissions**:
- `sqs:ReceiveMessage`, `sqs:DeleteMessage` on respective command queues
- CloudWatch Logs permissions
- VPC networking permissions

**Processing Logic**:
1. Receive command from SQS queue
2. Validate command format
3. Connect to ECS message broker
4. Publish command to appropriate MQTT topic
5. Log command execution

### 3.7 Data Synchronization

#### 3.7.1 EventBridge Sync Trigger

**Purpose**: Trigger data synchronization every 5 minutes

**Design Decisions**:
- Schedule expression: `rate(5 minutes)`
- Target: Lambda_Sync function
- Independent from ingestion trigger

**Terraform Module**: `eventbridge`

**Resources**:
- `aws_cloudwatch_event_rule.sync_trigger`
- `aws_cloudwatch_event_target.lambda_sync`

**Naming Convention**:
- Rule: `eventbridge-tilt-sensor-lab-sync`


#### 3.7.2 Lambda_Sync Function (data-transmission)

**Purpose**: Synchronize data from Aurora to Redis

**Design Decisions**:
- Runtime: Python 3.11
- Memory: 512 MB
- Timeout: 120 seconds
- VPC-enabled to access both Aurora and Redis

**Terraform Module**: `lambda`

**Resources**:
- `aws_lambda_function.sync`
- `aws_iam_role.lambda_sync`
- `aws_security_group.lambda_sync`

**Naming Convention**:
- Function: `lambda-tilt-sensor-lab-data-transmission`

**IAM Permissions**:
- `rds-db:connect` on Aurora cluster
- CloudWatch Logs permissions
- VPC networking permissions

**Synchronization Logic**:
1. Query Aurora for recent device status updates
2. Query Aurora for aggregated statistics
3. Update Redis cache with fresh data
4. Set appropriate TTL values
5. Log synchronization metrics

### 3.8 Security Layer

#### 3.8.1 CloudFront Distribution

**Purpose**: CDN and DDoS protection for web portal

**Design Decisions**:
- Origin: Application Load Balancer
- HTTPS only (redirect HTTP to HTTPS)
- Custom SSL certificate via ACM
- Caching policy for static assets

**Terraform Module**: `cloudfront`

**Resources**:
- `aws_cloudfront_distribution.portal`
- `aws_cloudfront_origin_access_identity.portal`

**Naming Convention**:
- Distribution: `cf-tilt-sensor-lab-portal`

**Configuration**:
```hcl
price_class = "PriceClass_100"
enabled     = true
http_version = "http2and3"
```


#### 3.8.2 AWS WAF

**Purpose**: Web application firewall for threat protection

**Design Decisions**:
- Attached to CloudFront distribution
- AWS Managed Rules: Core Rule Set, Known Bad Inputs
- Rate limiting: 2000 requests per 5 minutes per IP
- Geo-blocking (optional)

**Terraform Module**: `waf`

**Resources**:
- `aws_wafv2_web_acl.portal`
- `aws_wafv2_web_acl_association.cloudfront`

**Naming Convention**:
- Web ACL: `waf-tilt-sensor-lab-portal`

**Rules**:
1. AWS Managed Core Rule Set
2. AWS Managed Known Bad Inputs
3. Rate-based rule (2000 req/5min)
4. Custom rule for SQL injection protection

#### 3.8.3 IAM Roles and Policies

**Purpose**: Least-privilege access control

**Design Decisions**:
- Separate IAM role for each Lambda function
- Inline policies for specific resource access
- AWS managed policies for common services (CloudWatch Logs)

**Terraform Module**: `iam`

**Resources**:
- `aws_iam_role.lambda_*` (for each Lambda function)
- `aws_iam_policy.lambda_*` (custom policies)
- `aws_iam_role_policy_attachment.*`

**Naming Convention**:
- Roles: `iam-role-tilt-sensor-lab-lambda-{function_name}`
- Policies: `iam-policy-tilt-sensor-lab-lambda-{function_name}`

**Example Policy (Lambda_Parsing)**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sqs:SendMessage"
      ],
      "Resource": "arn:aws:sqs:*:*:sqs-fifo-tilt-sensor-lab-distributing.fifo"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```


#### 3.8.4 Security Groups

**Purpose**: Network-level access control

**Design Decisions**:
- Separate security group for each component
- Principle of least privilege
- No direct internet access for private resources

**Terraform Module**: Defined within respective component modules

**Security Group Matrix**:

| Component | Ingress | Egress |
|-----------|---------|--------|
| NLB | TCP 1883 (0.0.0.0/0) | TCP 1883 (ECS Broker SG) |
| ECS Broker | TCP 1883 (NLB SG), TCP 1883 (Lambda Parsing SG), TCP 1883 (Command Handler SGs) | All (for container pulls) |
| Lambda Parsing | None | TCP 1883 (ECS Broker SG), HTTPS 443 (SQS endpoint) |
| Lambda Distributing | None | HTTPS 443 (SQS endpoint) |
| Lambda DB1 | None | TCP 5432 (Aurora SG), HTTPS 443 (SQS endpoint) |
| Lambda Sync | None | TCP 5432 (Aurora SG), TCP 6379 (Redis SG) |
| Command Handlers | None | TCP 1883 (ECS Broker SG), HTTPS 443 (SQS endpoint) |
| Aurora | TCP 5432 (Lambda DB1 SG, Lambda Sync SG, EC2 Portal SG) | None |
| Redis | TCP 6379 (Lambda Sync SG, EC2 Portal SG) | None |
| ALB | HTTPS 443 (CloudFront IPs), HTTP 80 (CloudFront IPs) | HTTP 80 (EC2 Portal SG) |
| EC2 Portal | HTTP 80 (ALB SG) | TCP 5432 (Aurora SG), TCP 6379 (Redis SG), HTTPS 443 (SQS endpoint) |

**Naming Convention**:
- Security Groups: `sg-tilt-sensor-lab-{component}`


## 4. Data Flow Diagrams

### 4.1 Ingestion Pipeline Flow

```
IoT Devices
    ↓ (TCP/MQTT)
Network Load Balancer (Public Subnet)
    ↓
ECS Message Broker (Private Subnet)
    ↑ (Pull every 5 min)
EventBridge Rule → Lambda_Parsing
    ↓ (Parsed JSON)
SQS FIFO (sqs-fifo-distributing)
    ↓ (Trigger)
Lambda_Distributing
    ↓ (Route)
SQS Standard (sqs-db1)
    ↓ (Trigger)
Lambda_DB1
    ↓ (Write)
Aurora PostgreSQL
```

### 4.2 Command and Control Flow

```
EC2 Portal API
    ↓ (Commands)
SQS FIFO (mqtt-command.fifo / lorawan-command.fifo)
    ↓ (Trigger)
Lambda Command Handlers
    ↓ (Forward)
ECS Message Broker
    ↓ (MQTT Publish)
IoT Devices
```

### 4.3 Data Synchronization Flow

```
EventBridge Rule (5 min)
    ↓ (Trigger)
Lambda_Sync
    ↓ (Read)
Aurora PostgreSQL
    ↓ (Write)
ElastiCache Redis
    ↑ (Read)
EC2 Portal API
```

### 4.4 Web Portal Request Flow

```
End Users
    ↓ (HTTPS)
AWS WAF
    ↓ (Filter)
CloudFront
    ↓ (Route)
Application Load Balancer
    ↓ (Distribute)
EC2 Portal API
    ↓ (Query)
Aurora PostgreSQL / ElastiCache Redis
```


## 5. Terraform Module Structure

### 5.1 Module Organization

```
terraform/
├── main.tf                 # Root module orchestration
├── variables.tf            # Input variables
├── outputs.tf              # Output values
├── versions.tf             # Provider versions
├── terraform.tfvars        # Variable values
├── modules/
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   ├── nlb/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   ├── ecs/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   ├── lambda/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   ├── sqs/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   ├── rds/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   ├── elasticache/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   ├── ec2/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   ├── alb/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   ├── cloudfront/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   ├── waf/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   ├── eventbridge/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   └── iam/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
```


### 5.2 Key Variables

```hcl
# Project configuration
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

# Network configuration
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

# Ingestion configuration
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

# Lambda configuration
variable "lambda_parsing_memory" {
  description = "Memory for Lambda_Parsing function"
  type        = number
  default     = 512
}

variable "lambda_parsing_timeout" {
  description = "Timeout for Lambda_Parsing function"
  type        = number
  default     = 60
}

# ECS configuration
variable "ecs_task_cpu" {
  description = "CPU units for ECS task"
  type        = number
  default     = 512
}

variable "ecs_task_memory" {
  description = "Memory for ECS task"
  type        = number
  default     = 1024
}

# RDS configuration
variable "aurora_min_capacity" {
  description = "Minimum Aurora capacity"
  type        = number
  default     = 0.5
}

variable "aurora_max_capacity" {
  description = "Maximum Aurora capacity"
  type        = number
  default     = 2
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
```


### 5.3 Key Outputs

```hcl
# Network outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

# Load balancer outputs
output "nlb_dns_name" {
  description = "NLB DNS name for IoT devices"
  value       = module.nlb.dns_name
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.alb.dns_name
}

# Database outputs
output "aurora_endpoint" {
  description = "Aurora cluster endpoint"
  value       = module.rds.cluster_endpoint
  sensitive   = true
}

output "redis_endpoint" {
  description = "Redis primary endpoint"
  value       = module.elasticache.primary_endpoint
  sensitive   = true
}

# CloudFront output
output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = module.cloudfront.domain_name
}

# SQS outputs
output "sqs_fifo_distributing_url" {
  description = "SQS FIFO distributing queue URL"
  value       = module.sqs.fifo_distributing_url
}

output "sqs_db1_url" {
  description = "SQS DB1 queue URL"
  value       = module.sqs.db1_url
}

output "sqs_mqtt_command_url" {
  description = "SQS MQTT command queue URL"
  value       = module.sqs.mqtt_command_url
}

output "sqs_lorawan_command_url" {
  description = "SQS LoRaWAN command queue URL"
  value       = module.sqs.lorawan_command_url
}
```


## 6. Scalability and Performance

### 6.1 Scalability Considerations

**Horizontal Scaling**:
- ECS Fargate: Auto-scaling based on CPU/memory metrics
- EC2 Portal API: Auto Scaling Group (2-4 instances)
- Aurora: Serverless v2 auto-scaling (0.5-2 ACU)
- Lambda: Automatic scaling up to account limits

**Vertical Scaling**:
- ECS task size: Configurable CPU/memory
- EC2 instance type: Adjustable via launch template
- Lambda memory: Configurable per function
- Aurora capacity: Adjustable min/max ACU

### 6.2 Performance Optimization

**Batch Processing**:
- Lambda_Parsing: Pull multiple messages per invocation
- Lambda_Distributing: Process 10 messages per batch
- Lambda_DB1: Process 25 messages per batch

**Caching Strategy**:
- Redis TTL: 5 minutes for device status
- CloudFront caching: Static assets cached at edge
- Aurora query cache: Enabled for repeated queries

**Connection Pooling**:
- Lambda_DB1: Reuse database connections
- EC2 Portal API: Connection pool to Aurora and Redis

**Message Ordering**:
- SQS FIFO: Ensures critical messages processed first
- Message group ID: device_id for per-device ordering

### 6.3 Cost Optimization

**Scheduled Processing**:
- 5-minute intervals instead of real-time streaming
- Reduces Lambda invocations by 12x compared to per-message processing

**Serverless Components**:
- Lambda: Pay per invocation
- Aurora Serverless v2: Pay for actual capacity used
- Fargate: No idle EC2 costs

**Right-Sizing**:
- Lambda memory: Optimized per function
- ECS tasks: Minimal CPU/memory allocation
- EC2 instances: t3.medium for cost-effectiveness


## 7. High Availability and Disaster Recovery

### 7.1 High Availability Design

**Multi-AZ Deployment**:
- VPC subnets across 2 availability zones
- Aurora: Multi-AZ with automatic failover
- ElastiCache: Multi-AZ with automatic failover
- NLB and ALB: Cross-zone load balancing enabled

**Redundancy**:
- ECS: Minimum 2 tasks across AZs
- EC2 Portal API: Minimum 2 instances across AZs
- Aurora: 2 instances (1 writer, 1 reader)

**Health Checks**:
- NLB: TCP health checks on broker port
- ALB: HTTP health checks on /health endpoint
- ECS: Container health checks
- Auto Scaling: Instance health checks

### 7.2 Disaster Recovery

**Backup Strategy**:
- Aurora: Automated daily backups (7-day retention)
- Aurora: Continuous backup to S3
- Point-in-time recovery: Up to 35 days

**Recovery Objectives**:
- RTO (Recovery Time Objective): 15 minutes
- RPO (Recovery Point Objective): 5 minutes

**Failover Procedures**:
- Aurora: Automatic failover to standby (1-2 minutes)
- ElastiCache: Automatic failover to replica (< 1 minute)
- ECS: Automatic task replacement on failure
- EC2: Auto Scaling replaces unhealthy instances

### 7.3 Monitoring and Alerting

**CloudWatch Metrics**:
- Lambda: Invocations, errors, duration, throttles
- SQS: Messages visible, messages in flight, age of oldest message
- ECS: CPU utilization, memory utilization, task count
- Aurora: CPU utilization, connections, read/write latency
- ElastiCache: CPU utilization, evictions, cache hits/misses
- ALB/NLB: Request count, target response time, unhealthy hosts

**CloudWatch Alarms**:
- Lambda errors > 5% in 5 minutes
- SQS message age > 10 minutes
- Aurora CPU > 80% for 5 minutes
- ECS task count < 1
- ALB unhealthy target count > 0

**CloudWatch Logs**:
- Lambda function logs
- ECS container logs
- VPC Flow Logs (optional)
- WAF logs


## 8. Security Considerations

### 8.1 Network Security

**Network Segmentation**:
- Public subnets: Only load balancers
- Private subnets: All compute and storage resources
- No direct internet access for private resources

**Traffic Encryption**:
- HTTPS/TLS for all web traffic
- MQTTS (MQTT over TLS) for IoT device connections
- Encryption in transit for Aurora and Redis

**DDoS Protection**:
- CloudFront: Built-in DDoS protection
- AWS Shield Standard: Automatic protection
- WAF rate limiting: 2000 requests per 5 minutes

### 8.2 Data Security

**Encryption at Rest**:
- Aurora: AWS KMS encryption
- EBS volumes: Encrypted
- S3 (if used): Server-side encryption

**Encryption in Transit**:
- TLS 1.2+ for all HTTPS connections
- SSL/TLS for database connections
- MQTTS for IoT device connections

**Secrets Management**:
- Database credentials: AWS Secrets Manager
- API keys: AWS Secrets Manager or Parameter Store
- Lambda environment variables: Encrypted with KMS

### 8.3 Access Control

**IAM Best Practices**:
- Least-privilege policies for all roles
- No wildcard permissions in production
- Service-specific roles (no shared roles)
- MFA required for console access

**Network Access Control**:
- Security groups: Whitelist-based rules
- NACLs: Additional layer of defense (optional)
- VPC endpoints: Private access to AWS services

**Audit and Compliance**:
- CloudTrail: All API calls logged
- Config: Resource configuration tracking
- GuardDuty: Threat detection (optional)


## 9. Deployment Strategy

### 9.1 Terraform Deployment Phases

**Phase 1: Foundation (Network)**
```bash
terraform apply -target=module.vpc
```
- VPC, subnets, Internet Gateway, route tables

**Phase 2: Security**
```bash
terraform apply -target=module.iam -target=module.waf
```
- IAM roles and policies
- WAF Web ACL

**Phase 3: Storage Layer**
```bash
terraform apply -target=module.rds -target=module.elasticache
```
- Aurora PostgreSQL cluster
- ElastiCache Redis cluster

**Phase 4: Messaging Layer**
```bash
terraform apply -target=module.sqs -target=module.eventbridge
```
- SQS queues (FIFO and Standard)
- EventBridge rules

**Phase 5: Compute Layer**
```bash
terraform apply -target=module.ecs -target=module.lambda
```
- ECS cluster and message broker
- All Lambda functions

**Phase 6: Load Balancers**
```bash
terraform apply -target=module.nlb -target=module.alb
```
- Network Load Balancer
- Application Load Balancer

**Phase 7: Application Layer**
```bash
terraform apply -target=module.ec2
```
- EC2 Auto Scaling Group
- Portal API instances

**Phase 8: CDN and Security**
```bash
terraform apply -target=module.cloudfront
```
- CloudFront distribution

**Phase 9: Full Deployment**
```bash
terraform apply
```
- Apply all remaining resources and dependencies

### 9.2 Post-Deployment Steps

1. **Database Initialization**:
   - Connect to Aurora cluster
   - Run schema creation scripts
   - Create initial tables and indexes

2. **Lambda Function Code Deployment**:
   - Package Lambda function code
   - Upload to S3 or deploy via Terraform
   - Update function configurations

3. **ECS Container Image**:
   - Build message broker Docker image
   - Push to ECR
   - Update ECS task definition

4. **SSL Certificate**:
   - Request ACM certificate for domain
   - Validate domain ownership
   - Associate with ALB and CloudFront

5. **DNS Configuration**:
   - Create Route 53 hosted zone
   - Point domain to CloudFront distribution
   - Create A record for IoT device endpoint (NLB)

6. **Testing**:
   - Test IoT device connectivity to NLB
   - Test web portal access via CloudFront
   - Verify data flow through pipeline
   - Test command and control functionality


## 10. Testing Strategy

### 10.1 Unit Testing

**Terraform Validation**:
```bash
terraform fmt -check
terraform validate
terraform plan
```

**Lambda Function Testing**:
- Unit tests for parsing logic
- Unit tests for routing logic
- Unit tests for database operations
- Mock SQS, Aurora, and Redis connections

### 10.2 Integration Testing

**Pipeline Testing**:
1. Send test message to ECS broker
2. Trigger Lambda_Parsing manually
3. Verify message in sqs-fifo-distributing
4. Verify message routing to sqs-db1
5. Verify data persisted in Aurora

**Command Testing**:
1. Send command via EC2 Portal API
2. Verify command in SQS command queue
3. Verify command handler execution
4. Verify command forwarded to broker

**Sync Testing**:
1. Insert test data in Aurora
2. Trigger Lambda_Sync manually
3. Verify data in Redis cache
4. Verify TTL settings

### 10.3 Load Testing

**IoT Device Simulation**:
- Simulate 1000 concurrent device connections
- Send messages at varying rates
- Monitor NLB and ECS metrics

**API Load Testing**:
- Simulate 500 concurrent users
- Test various API endpoints
- Monitor ALB, EC2, Aurora, and Redis metrics

**Pipeline Throughput**:
- Test with 10,000 messages per 5-minute interval
- Monitor Lambda concurrency and SQS metrics
- Verify no message loss or throttling

### 10.4 Security Testing

**Penetration Testing**:
- Test WAF rules effectiveness
- Attempt SQL injection attacks
- Test rate limiting

**Access Control Testing**:
- Verify IAM policies enforce least privilege
- Test security group rules
- Verify encryption in transit and at rest


## 11. Operational Procedures

### 11.1 Routine Operations

**Daily Checks**:
- Review CloudWatch dashboards
- Check alarm status
- Monitor SQS queue depths
- Review Lambda error rates

**Weekly Maintenance**:
- Review CloudWatch Logs for errors
- Analyze cost reports
- Review security group rules
- Check for AWS service updates

**Monthly Tasks**:
- Review and optimize Lambda memory settings
- Analyze Aurora performance insights
- Review and update IAM policies
- Test disaster recovery procedures

### 11.2 Troubleshooting Procedures

**High SQS Queue Depth**:
1. Check Lambda function errors
2. Increase Lambda concurrency if needed
3. Check database connection limits
4. Review CloudWatch Logs for specific errors

**Lambda Timeout Errors**:
1. Review function execution time metrics
2. Optimize code or increase timeout
3. Check network connectivity to dependencies
4. Review database query performance

**Database Connection Errors**:
1. Check Aurora connection count
2. Review Lambda connection pooling
3. Increase Aurora capacity if needed
4. Check security group rules

**ECS Task Failures**:
1. Review ECS task logs
2. Check container health checks
3. Verify ECR image availability
4. Review task resource allocation

### 11.3 Scaling Procedures

**Increase IoT Device Capacity**:
1. Increase ECS task count
2. Adjust NLB target group settings
3. Monitor ECS CPU/memory metrics

**Increase API Capacity**:
1. Increase EC2 Auto Scaling Group max size
2. Adjust ALB target group settings
3. Monitor EC2 CPU/memory metrics

**Increase Database Capacity**:
1. Increase Aurora max ACU
2. Add read replicas if needed
3. Optimize slow queries


## 12. Cost Estimation

### 12.1 Monthly Cost Breakdown (Estimated)

**Compute**:
- Lambda (5 functions, 288 invocations/day each): $5-10
- ECS Fargate (2 tasks, 0.5 vCPU, 1GB): $30-40
- EC2 (2 t3.medium instances): $60-70

**Storage**:
- Aurora Serverless v2 (0.5-2 ACU): $40-80
- ElastiCache Redis (2 cache.t3.micro nodes): $25-30
- EBS volumes (EC2): $10-15

**Networking**:
- Network Load Balancer: $20-25
- Application Load Balancer: $20-25
- Data transfer: $10-20
- NAT Gateway (if used): $30-40

**Messaging**:
- SQS (5 queues, 1M requests/month): $1-2
- EventBridge (2 rules, 8,640 invocations/month): $0.10

**Security & CDN**:
- CloudFront (1TB data transfer): $85-100
- AWS WAF: $5-10
- ACM certificates: Free

**Total Estimated Monthly Cost**: $340-470

*Note: Costs vary based on actual usage, region, and data transfer volumes*

### 12.2 Cost Optimization Recommendations

1. **Use Reserved Instances**: Save 30-40% on EC2 costs
2. **Right-size Resources**: Monitor and adjust based on actual usage
3. **Implement S3 Lifecycle Policies**: Archive old data to Glacier
4. **Use VPC Endpoints**: Reduce NAT Gateway costs
5. **Optimize Lambda Memory**: Balance performance and cost
6. **Schedule Non-Production Resources**: Stop dev/test resources when not in use


## 13. Future Enhancements

### 13.1 Short-term Enhancements (3-6 months)

1. **Real-time Alerting**:
   - SNS notifications for critical alarms
   - Email/SMS alerts for device failures
   - Integration with PagerDuty or similar

2. **Advanced Analytics**:
   - Kinesis Data Analytics for real-time insights
   - QuickSight dashboards for visualization
   - Anomaly detection using ML

3. **Device Management**:
   - AWS IoT Device Management integration
   - Over-the-air (OTA) firmware updates
   - Device shadow for state management

4. **API Gateway**:
   - Replace direct EC2 access with API Gateway
   - API throttling and usage plans
   - API key management

### 13.2 Long-term Enhancements (6-12 months)

1. **Multi-Region Deployment**:
   - Active-active or active-passive setup
   - Route 53 health checks and failover
   - Cross-region replication for Aurora

2. **Advanced Security**:
   - AWS IoT Core for device authentication
   - Certificate-based device authentication
   - AWS Security Hub integration

3. **Serverless Migration**:
   - Replace EC2 with Lambda + API Gateway
   - Use Aurora Serverless v2 exclusively
   - Reduce operational overhead

4. **Data Lake Integration**:
   - Stream data to S3 via Kinesis Firehose
   - Glue for ETL and data cataloging
   - Athena for ad-hoc queries

5. **Machine Learning**:
   - SageMaker for predictive maintenance
   - Forecast for capacity planning
   - Rekognition for image analysis (if applicable)


## 14. Correctness Properties

The following properties define the correctness criteria for the IoT Tilt Sensor Monitoring System. These properties will be validated through property-based testing during implementation.

### 14.1 Data Ingestion Properties

**Property 1.1: Message Ordering Preservation**
- **Specification**: For any device_id, messages SHALL be processed in the order they are received by the FIFO queue
- **Validation**: Given a sequence of messages M1, M2, M3 with the same device_id and timestamps T1 < T2 < T3, the database SHALL contain entries in chronological order
- **Test Strategy**: Generate random message sequences per device, verify database ordering matches input ordering

**Property 1.2: No Message Loss**
- **Specification**: Every message successfully sent to sqs-fifo-distributing SHALL eventually be persisted in Aurora or moved to DLQ
- **Validation**: For any message M sent to the queue, either Aurora contains M or DLQ contains M within timeout period
- **Test Strategy**: Send N messages, verify count(Aurora) + count(DLQ) = N

**Property 1.3: Idempotency**
- **Specification**: Processing the same message multiple times SHALL NOT create duplicate database entries
- **Validation**: Given a message M with unique (device_id, timestamp), inserting M multiple times SHALL result in exactly one database row
- **Test Strategy**: Send duplicate messages, verify single database entry per unique (device_id, timestamp)

### 14.2 Command and Control Properties

**Property 2.1: Command Delivery**
- **Specification**: Every command sent to a command queue SHALL be forwarded to the message broker within timeout period
- **Validation**: For any command C sent to mqtt-command.fifo or lorawan-command.fifo, the broker SHALL receive C within 60 seconds
- **Test Strategy**: Send commands, monitor broker logs for receipt confirmation

**Property 2.2: Command Ordering**
- **Specification**: Commands for the same device SHALL be processed in FIFO order
- **Validation**: Given commands C1, C2, C3 for device D sent at T1 < T2 < T3, broker SHALL receive them in order C1, C2, C3
- **Test Strategy**: Send sequential commands per device, verify broker receipt order

### 14.3 Data Synchronization Properties

**Property 3.1: Cache Consistency**
- **Specification**: After Lambda_Sync execution, Redis SHALL contain data consistent with Aurora for the synchronized dataset
- **Validation**: For any device status in Aurora at time T, Redis SHALL contain the same status after sync at T+5min
- **Test Strategy**: Update Aurora, trigger sync, verify Redis matches Aurora

**Property 3.2: Cache Freshness**
- **Specification**: Cached data in Redis SHALL NOT be older than 10 minutes
- **Validation**: For any cached entry E, timestamp(E) SHALL be within 10 minutes of current time
- **Test Strategy**: Query Redis entries, verify all timestamps are recent


### 14.4 Security Properties

**Property 4.1: Network Isolation**
- **Specification**: Private subnet resources SHALL NOT be directly accessible from the internet
- **Validation**: Attempting to connect to Aurora, Redis, or ECS from external IP SHALL fail
- **Test Strategy**: Attempt direct connections from external network, verify all fail

**Property 4.2: Least Privilege IAM**
- **Specification**: Each Lambda function SHALL have access ONLY to resources required for its operation
- **Validation**: Lambda_Parsing SHALL have SQS SendMessage permission but NOT RDS access; Lambda_DB1 SHALL have RDS access but NOT SQS SendMessage to command queues
- **Test Strategy**: Review IAM policies, attempt unauthorized actions, verify denials

**Property 4.3: Encryption in Transit**
- **Specification**: All data transmission between components SHALL use encryption (TLS/SSL)
- **Validation**: Connections to Aurora, Redis, and HTTPS endpoints SHALL use encrypted protocols
- **Test Strategy**: Monitor network traffic, verify TLS/SSL usage

### 14.5 Availability Properties

**Property 5.1: Multi-AZ Resilience**
- **Specification**: System SHALL remain operational if one availability zone fails
- **Validation**: Simulating AZ failure SHALL NOT cause complete system outage
- **Test Strategy**: Disable resources in one AZ, verify system continues processing

**Property 5.2: Auto-Recovery**
- **Specification**: Failed Lambda invocations SHALL be retried automatically
- **Validation**: Lambda failures SHALL trigger retries up to configured limit
- **Test Strategy**: Inject failures, verify retry behavior

### 14.6 Performance Properties

**Property 6.1: Processing Latency**
- **Specification**: Messages SHALL be processed from broker to database within 10 minutes under normal load
- **Validation**: For any message M arriving at broker at time T, M SHALL be in Aurora by T+10min
- **Test Strategy**: Send messages, measure end-to-end latency

**Property 6.2: Throughput Capacity**
- **Specification**: System SHALL process at least 10,000 messages per 5-minute interval
- **Validation**: Sending 10,000 messages SHALL NOT cause throttling or message loss
- **Test Strategy**: Load test with 10,000 messages, verify all processed successfully


## 15. Acceptance Criteria Mapping

This section maps the requirements from the requirements document to the design components and correctness properties.

### 15.1 Network Infrastructure (Requirement 3.1)

**Requirement 1.1**: Multi-tier network with public/private subnets across 2 AZs
- **Design Component**: VPC Module (Section 3.1)
- **Validation**: Property 5.1 (Multi-AZ Resilience)

**Requirement 1.2**: Internet Gateway for public subnet access
- **Design Component**: VPC Module (Section 3.1)
- **Validation**: Manual verification of IGW attachment

### 15.2 IoT Data Ingestion (Requirement 3.2)

**Requirement 2.1-2.3**: NLB and ECS Message Broker
- **Design Component**: NLB Module (Section 3.2.1), ECS Module (Section 3.2.2)
- **Validation**: Integration testing (Section 10.2)

**Requirement 2.4-2.6**: EventBridge scheduled trigger
- **Design Component**: EventBridge Module (Section 3.3.1)
- **Validation**: Manual trigger verification

**Requirement 2.7-2.9**: Lambda_Parsing pulls and parses data
- **Design Component**: Lambda_Parsing (Section 3.3.2)
- **Validation**: Unit tests for parsing logic

**Requirement 2.10-2.12**: SQS FIFO and Lambda_Distributing
- **Design Component**: SQS Module (Section 3.3.3), Lambda_Distributing (Section 3.3.4)
- **Validation**: Property 1.1 (Message Ordering Preservation)

**Requirement 2.13-2.14**: SQS Standard buffer and routing
- **Design Component**: SQS Module (Section 3.3.5)
- **Validation**: Property 1.2 (No Message Loss)

**Requirement 2.15**: Lambda_DB1 persistence
- **Design Component**: Lambda_DB1 (Section 3.3.6)
- **Validation**: Property 1.3 (Idempotency), Property 6.1 (Processing Latency)

### 15.3 Application Backend (Requirement 3.3)

**Requirement 3.1-3.2**: EC2 Portal API and ALB
- **Design Component**: EC2 Module (Section 3.5.1), ALB Module (Section 3.5.2)
- **Validation**: Load testing (Section 10.3)

**Requirement 3.3-3.5**: Aurora and Redis storage
- **Design Component**: RDS Module (Section 3.4.1), ElastiCache Module (Section 3.4.2)
- **Validation**: Property 3.1 (Cache Consistency)

**Requirement 3.6-3.7**: CloudFront and WAF
- **Design Component**: CloudFront Module (Section 3.8.1), WAF Module (Section 3.8.2)
- **Validation**: Security testing (Section 10.4)

### 15.4 Command and Control (Requirement 3.4)

**Requirement 4.1-4.4**: Command queues and handlers
- **Design Component**: SQS Module (Section 3.6.1), Command Handlers (Section 3.6.2)
- **Validation**: Property 2.1 (Command Delivery), Property 2.2 (Command Ordering)

### 15.5 Data Synchronization (Requirement 3.5)

**Requirement 5.1-5.3**: Lambda_Sync function
- **Design Component**: Lambda_Sync (Section 3.7.2)
- **Validation**: Property 3.1 (Cache Consistency), Property 3.2 (Cache Freshness)

### 15.6 Security (Requirement 3.6)

**Requirement 6.1-6.3**: IAM roles and security groups
- **Design Component**: IAM Module (Section 3.8.3), Security Groups (Section 3.8.4)
- **Validation**: Property 4.1 (Network Isolation), Property 4.2 (Least Privilege IAM)

### 15.7 Infrastructure as Code (Requirement 3.7)

**Requirement 7.1-7.3**: Modular Terraform code
- **Design Component**: Terraform Module Structure (Section 5)
- **Validation**: Terraform validation (Section 10.1)


## 16. Assumptions and Constraints

### 16.1 Assumptions

1. **IoT Device Protocol**: Devices use MQTT protocol for communication
2. **Message Format**: Devices send data in a consistent format that can be parsed to JSON
3. **Device Authentication**: Device authentication is handled by the message broker (not in scope for infrastructure)
4. **AWS Region**: Deployment in a single AWS region (us-east-1 assumed)
5. **Domain Name**: Customer will provide domain name for CloudFront and ALB
6. **SSL Certificates**: Customer will validate ACM certificates for their domain
7. **Database Schema**: Schema provided in design will be implemented by application team
8. **Message Volume**: Expected load of ~10,000 messages per 5-minute interval
9. **Retention Period**: Sensor data retained for 90 days (application-level policy)
10. **Business Hours**: System operates 24/7 with no maintenance windows

### 16.2 Constraints

1. **Budget**: Monthly infrastructure cost target of $400-500
2. **Compliance**: No specific compliance requirements (HIPAA, PCI-DSS, etc.)
3. **Latency**: Maximum 10-minute end-to-end processing latency acceptable
4. **Availability**: Target 99.5% uptime (no SLA requirement)
5. **Scalability**: System designed for up to 1,000 concurrent devices initially
6. **Data Retention**: Aurora backups retained for 7 days (not 35 days)
7. **Geographic Scope**: Single region deployment (no multi-region requirement)
8. **Team Size**: Small DevOps team (1-2 engineers) for maintenance
9. **Deployment Frequency**: Infrastructure changes deployed monthly
10. **Monitoring**: CloudWatch only (no third-party monitoring tools)

### 16.3 Out of Scope

1. **Frontend Web Application**: UI/UX design and implementation
2. **Mobile Applications**: iOS/Android apps for device management
3. **Device Firmware**: IoT device software and firmware updates
4. **Data Analytics**: Advanced analytics and machine learning models
5. **Billing System**: Usage tracking and billing for end customers
6. **User Management**: User authentication and authorization (assumed handled by application)
7. **Reporting**: Custom report generation and scheduling
8. **Third-party Integrations**: Integration with external systems (CRM, ERP, etc.)
9. **Multi-tenancy**: Tenant isolation and management
10. **Disaster Recovery Testing**: Formal DR drills and documentation


## 17. Glossary

- **ACU**: Aurora Capacity Unit - unit of compute capacity for Aurora Serverless
- **ALB**: Application Load Balancer - Layer 7 load balancer for HTTP/HTTPS traffic
- **AZ**: Availability Zone - isolated location within an AWS region
- **CIDR**: Classless Inter-Domain Routing - IP address allocation method
- **DLQ**: Dead Letter Queue - queue for messages that failed processing
- **ECS**: Elastic Container Service - container orchestration service
- **FIFO**: First In First Out - queue type that preserves message order
- **IAM**: Identity and Access Management - AWS access control service
- **KMS**: Key Management Service - encryption key management
- **MQTT**: Message Queuing Telemetry Transport - lightweight IoT protocol
- **NLB**: Network Load Balancer - Layer 4 load balancer for TCP/UDP traffic
- **SQS**: Simple Queue Service - managed message queue service
- **TLS**: Transport Layer Security - encryption protocol for data in transit
- **TTL**: Time To Live - expiration time for cached data
- **VPC**: Virtual Private Cloud - isolated network environment in AWS
- **WAF**: Web Application Firewall - protection against web exploits

## 18. References

### 18.1 AWS Documentation

- [Amazon VPC User Guide](https://docs.aws.amazon.com/vpc/)
- [Amazon ECS Developer Guide](https://docs.aws.amazon.com/ecs/)
- [AWS Lambda Developer Guide](https://docs.aws.amazon.com/lambda/)
- [Amazon SQS Developer Guide](https://docs.aws.amazon.com/sqs/)
- [Amazon Aurora User Guide](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/)
- [Amazon ElastiCache User Guide](https://docs.aws.amazon.com/elasticache/)
- [AWS WAF Developer Guide](https://docs.aws.amazon.com/waf/)
- [Amazon CloudFront Developer Guide](https://docs.aws.amazon.com/cloudfront/)

### 18.2 Terraform Documentation

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)

### 18.3 Architecture Patterns

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [AWS IoT Reference Architectures](https://aws.amazon.com/iot/solutions/)

---

**Document Version**: 1.0  
**Last Updated**: 2026-01-18  
**Status**: Approved
**Author**: Kiro AI Assistant  
**Reviewers**: TBD
