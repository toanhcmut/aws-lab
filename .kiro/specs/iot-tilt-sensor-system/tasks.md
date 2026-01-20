# Implementation Tasks: IoT Tilt Sensor Monitoring System

## Phase 1: Foundation Setup

### 1.1 Project Structure and Configuration
- [ ] 1.1.1 Create Terraform project directory structure (terraform/, modules/)
  - **Validates**: Requirements 7.1
  - **Details**: Create root terraform/ directory with subdirectories for modules (vpc, nlb, ecs, lambda, sqs, rds, elasticache, ec2, alb, cloudfront, waf, eventbridge, iam)

- [ ] 1.1.2 Create root Terraform configuration files (main.tf, variables.tf, outputs.tf, versions.tf)
  - **Validates**: Requirements 7.1, 7.2
  - **Details**: Define AWS provider version ~> 5.0, configure backend (S3 + DynamoDB for state locking), define common variables (project, app, env, region, vpc_cidr, availability_zones)

- [ ] 1.1.3 Create terraform.tfvars with project-specific values
  - **Validates**: Requirements 7.2
  - **Details**: Set project="tilt", app="sensor", env="lab", region="us-east-1", vpc_cidr="10.0.0.0/16", availability_zones=["us-east-1a", "us-east-1b"]

## Phase 2: Network Infrastructure

### 2.1 VPC Module
- [ ] 2.1.1 Create VPC module structure (modules/vpc/)
  - **Validates**: Requirements 1.1, 1.2
  - **Details**: Create main.tf, variables.tf, outputs.tf in modules/vpc/

- [ ] 2.1.2 Implement VPC resources using terraform-aws-modules/vpc/aws
  - **Validates**: Requirements 1.1
  - **Details**: Use official VPC module, configure VPC with CIDR 10.0.0.0/16, create 2 public subnets (10.0.1.0/24, 10.0.2.0/24) and 2 private subnets (10.0.10.0/24, 10.0.11.0/24) across 2 AZs

- [ ] 2.1.3 Implement Internet Gateway and route tables
  - **Validates**: Requirements 1.2
  - **Details**: Create IGW, public route table with 0.0.0.0/0 -> IGW route, private route table, associate subnets with appropriate route tables


- [ ] 2.1.4 Add VPC outputs (vpc_id, public_subnet_ids, private_subnet_ids)
  - **Validates**: Requirements 7.3
  - **Details**: Export VPC ID, subnet IDs, route table IDs for use by other modules

- [ ] 2.1.5 Apply mandatory tags to all VPC resources
  - **Validates**: Terraform naming conventions
  - **Details**: Add tags: Project="TiltSensor", Environment="Lab", CreatedBy="Kiro-Intern", ManagedBy="Terraform"

## Phase 3: Security Layer

### 3.1 IAM Module
- [ ] 3.1.1 Create IAM module structure (modules/iam/)
  - **Validates**: Requirements 6.1
  - **Details**: Create main.tf, variables.tf, outputs.tf in modules/iam/

- [ ] 3.1.2 Create IAM role and policy for Lambda_Parsing
  - **Validates**: Requirements 6.1
  - **Details**: Role: iam-role-tilt-sensor-lab-lambda-parsing, permissions: sqs:SendMessage on sqs-fifo-distributing, CloudWatch Logs, VPC networking (ec2:CreateNetworkInterface, ec2:DescribeNetworkInterfaces, ec2:DeleteNetworkInterface)

- [ ] 3.1.3 Create IAM role and policy for Lambda_Distributing
  - **Validates**: Requirements 6.1
  - **Details**: Role: iam-role-tilt-sensor-lab-lambda-distributing, permissions: sqs:ReceiveMessage/DeleteMessage/GetQueueAttributes on sqs-fifo-distributing, sqs:SendMessage on sqs-db1, CloudWatch Logs

- [ ] 3.1.4 Create IAM role and policy for Lambda_DB1
  - **Validates**: Requirements 6.1
  - **Details**: Role: iam-role-tilt-sensor-lab-lambda-db1, permissions: sqs:ReceiveMessage/DeleteMessage/GetQueueAttributes on sqs-db1, rds-db:connect on Aurora, CloudWatch Logs, VPC networking

- [ ] 3.1.5 Create IAM role and policy for Lambda_Sync
  - **Validates**: Requirements 6.1
  - **Details**: Role: iam-role-tilt-sensor-lab-lambda-sync, permissions: rds-db:connect on Aurora, CloudWatch Logs, VPC networking

- [ ] 3.1.6 Create IAM roles for Command Handler Lambda functions
  - **Validates**: Requirements 6.1
  - **Details**: Roles for mqtt-command-handler and lorawan-command-handler with permissions: sqs:ReceiveMessage/DeleteMessage on respective queues, CloudWatch Logs, VPC networking

- [ ] 3.1.7 Create IAM role for ECS tasks
  - **Validates**: Requirements 6.1
  - **Details**: Role: iam-role-tilt-sensor-lab-ecs-task, permissions: ecr:GetAuthorizationToken, ecr:BatchCheckLayerAvailability, ecr:GetDownloadUrlForLayer, ecr:BatchGetImage, CloudWatch Logs

- [ ] 3.1.8 Create IAM role for EC2 instances (Portal API)
  - **Validates**: Requirements 6.1
  - **Details**: Role: iam-role-tilt-sensor-lab-ec2-portal, permissions: sqs:SendMessage on command queues, CloudWatch Logs, SSM Session Manager

### 3.2 Security Groups
- [ ] 3.2.1 Create security group for NLB
  - **Validates**: Requirements 6.2
  - **Details**: SG: sg-tilt-sensor-lab-nlb, Ingress: TCP 1883 from 0.0.0.0/0, Egress: TCP 1883 to ECS Broker SG

- [ ] 3.2.2 Create security group for ECS Message Broker
  - **Validates**: Requirements 6.2, 6.3
  - **Details**: SG: sg-tilt-sensor-lab-ecs-broker, Ingress: TCP 1883 from NLB SG, Lambda Parsing SG, Command Handler SGs, Egress: All (for container pulls)

- [ ] 3.2.3 Create security groups for Lambda functions
  - **Validates**: Requirements 6.2
  - **Details**: SGs for Lambda_Parsing, Lambda_DB1, Lambda_Sync, Command Handlers with appropriate egress rules to ECS, Aurora, Redis, SQS endpoints

- [ ] 3.2.4 Create security group for Aurora PostgreSQL
  - **Validates**: Requirements 6.2, 6.3
  - **Details**: SG: sg-tilt-sensor-lab-aurora, Ingress: TCP 5432 from Lambda_DB1 SG, Lambda_Sync SG, EC2 Portal SG, No egress

- [ ] 3.2.5 Create security group for ElastiCache Redis
  - **Validates**: Requirements 6.2, 6.3
  - **Details**: SG: sg-tilt-sensor-lab-redis, Ingress: TCP 6379 from Lambda_Sync SG, EC2 Portal SG, No egress

- [ ] 3.2.6 Create security group for ALB
  - **Validates**: Requirements 6.2
  - **Details**: SG: sg-tilt-sensor-lab-alb, Ingress: HTTPS 443 and HTTP 80 from CloudFront IP ranges, Egress: HTTP 80 to EC2 Portal SG

- [ ] 3.2.7 Create security group for EC2 Portal API
  - **Validates**: Requirements 6.2
  - **Details**: SG: sg-tilt-sensor-lab-ec2-portal, Ingress: HTTP 80 from ALB SG, Egress: TCP 5432 to Aurora SG, TCP 6379 to Redis SG, HTTPS 443 to SQS endpoints

### 3.3 WAF Module
- [ ] 3.3.1 Create WAF module structure (modules/waf/)
  - **Validates**: Requirements 3.6
  - **Details**: Create main.tf, variables.tf, outputs.tf in modules/waf/

- [ ] 3.3.2 Implement WAF Web ACL with managed rules
  - **Validates**: Requirements 3.6
  - **Details**: Web ACL: waf-tilt-sensor-lab-portal, Rules: AWS Managed Core Rule Set, AWS Managed Known Bad Inputs, Rate-based rule (2000 req/5min), Custom SQL injection protection

## Phase 4: Storage Layer

### 4.1 RDS Module (Aurora PostgreSQL)
- [ ] 4.1.1 Create RDS module structure (modules/rds/)
  - **Validates**: Requirements 3.3
  - **Details**: Create main.tf, variables.tf, outputs.tf in modules/rds/

- [ ] 4.1.2 Implement Aurora PostgreSQL cluster using terraform-aws-modules/rds-aurora/aws
  - **Validates**: Requirements 3.3
  - **Details**: Use official RDS Aurora module, cluster: rds-tilt-sensor-lab-aurora, engine: aurora-postgresql 15.4, serverless v2, min_capacity: 0.5 ACU, max_capacity: 2 ACU, multi-AZ, deployed in private subnets

- [ ] 4.1.3 Configure Aurora security settings
  - **Validates**: Requirements 3.3
  - **Details**: Enable encryption at rest (KMS), automated backups (7-day retention), associate with Aurora security group, create DB subnet group

- [ ] 4.1.4 Add Aurora outputs (cluster_endpoint, reader_endpoint)
  - **Validates**: Requirements 7.3
  - **Details**: Export cluster endpoint, reader endpoint, cluster identifier

### 4.2 ElastiCache Module (Redis)
- [ ] 4.2.1 Create ElastiCache module structure (modules/elasticache/)
  - **Validates**: Requirements 3.4
  - **Details**: Create main.tf, variables.tf, outputs.tf in modules/elasticache/

- [ ] 4.2.2 Implement Redis replication group
  - **Validates**: Requirements 3.4
  - **Details**: Replication group: redis-tilt-sensor-lab, engine: redis 7.0, node_type: cache.t3.micro, 2 nodes, multi-AZ with automatic failover, deployed in private subnets

- [ ] 4.2.3 Configure Redis security settings
  - **Validates**: Requirements 3.4
  - **Details**: Enable encryption in transit, associate with Redis security group, create subnet group

- [ ] 4.2.4 Add Redis outputs (primary_endpoint, reader_endpoint)
  - **Validates**: Requirements 7.3
  - **Details**: Export primary endpoint, reader endpoint, replication group ID

## Phase 5: Messaging Layer

### 5.1 SQS Module
- [ ] 5.1.1 Create SQS module structure (modules/sqs/)
  - **Validates**: Requirements 2.10, 2.13, 4.1
  - **Details**: Create main.tf, variables.tf, outputs.tf in modules/sqs/

- [ ] 5.1.2 Create SQS FIFO queue (sqs-fifo-distributing)
  - **Validates**: Requirements 2.10
  - **Details**: Queue: sqs-fifo-tilt-sensor-lab-distributing.fifo, FIFO enabled, content-based deduplication, visibility_timeout: 90s, message_retention: 4 days

- [ ] 5.1.3 Create SQS Standard queue (sqs-db1) with DLQ
  - **Validates**: Requirements 2.13
  - **Details**: Queue: sqs-tilt-sensor-lab-db1, DLQ: sqs-tilt-sensor-lab-db1-dlq, visibility_timeout: 120s, message_retention: 4 days, max_receive_count: 3

- [ ] 5.1.4 Create SQS FIFO queues for commands
  - **Validates**: Requirements 4.1
  - **Details**: Queues: sqs-fifo-tilt-sensor-lab-mqtt-command.fifo, sqs-fifo-tilt-sensor-lab-lorawan-command.fifo, FIFO enabled, content-based deduplication

- [ ] 5.1.5 Add SQS outputs (queue URLs and ARNs)
  - **Validates**: Requirements 7.3
  - **Details**: Export URLs and ARNs for all queues

### 5.2 EventBridge Module
- [ ] 5.2.1 Create EventBridge module structure (modules/eventbridge/)
  - **Validates**: Requirements 2.4, 5.2
  - **Details**: Create main.tf, variables.tf, outputs.tf in modules/eventbridge/

- [ ] 5.2.2 Create EventBridge rule for ingestion trigger
  - **Validates**: Requirements 2.4, 2.5, 2.6
  - **Details**: Rule: eventbridge-tilt-sensor-lab-ingestion, schedule: rate(5 minutes), target: Lambda_Parsing, retry policy: 2 retries with exponential backoff

- [ ] 5.2.3 Create EventBridge rule for sync trigger
  - **Validates**: Requirements 5.2
  - **Details**: Rule: eventbridge-tilt-sensor-lab-sync, schedule: rate(5 minutes), target: Lambda_Sync

- [ ] 5.2.4 Create Lambda permissions for EventBridge invocation
  - **Validates**: Requirements 2.6
  - **Details**: Allow EventBridge to invoke Lambda_Parsing and Lambda_Sync

## Phase 6: Compute Layer - ECS

### 6.1 ECS Module
- [ ] 6.1.1 Create ECS module structure (modules/ecs/)
  - **Validates**: Requirements 2.2
  - **Details**: Create main.tf, variables.tf, outputs.tf in modules/ecs/

- [ ] 6.1.2 Create ECS cluster
  - **Validates**: Requirements 2.2
  - **Details**: Cluster: ecs-tilt-sensor-lab, enable Container Insights

- [ ] 6.1.3 Create ECS task definition for Message Broker
  - **Validates**: Requirements 2.2
  - **Details**: Task: ecs-task-tilt-sensor-lab-broker, Fargate, CPU: 512, Memory: 1024, container image: eclipse-mosquitto or equivalent MQTT broker, port: 1883

- [ ] 6.1.4 Create ECS service for Message Broker
  - **Validates**: Requirements 2.2, 2.3
  - **Details**: Service: ecs-service-tilt-sensor-lab-broker, desired_count: 2, deployed in private subnets, associate with ECS Broker security group, register with NLB target group

- [ ] 6.1.5 Configure ECS service auto-scaling
  - **Validates**: Design scalability requirements
  - **Details**: Auto-scaling based on CPU/memory utilization, min: 2, max: 4

### 6.2 NLB Module
- [ ] 6.2.1 Create NLB module structure (modules/nlb/)
  - **Validates**: Requirements 2.1, 2.3
  - **Details**: Create main.tf, variables.tf, outputs.tf in modules/nlb/

- [ ] 6.2.2 Create Network Load Balancer
  - **Validates**: Requirements 2.1
  - **Details**: NLB: nlb-tilt-sensor-lab-iot, type: network, deployed in public subnets, cross-zone load balancing enabled

- [ ] 6.2.3 Create NLB target group for ECS
  - **Validates**: Requirements 2.3
  - **Details**: Target group: tg-tilt-sensor-lab-ecs-broker, target_type: ip, protocol: TCP, port: 1883, health check on port 1883

- [ ] 6.2.4 Create NLB listener
  - **Validates**: Requirements 2.1, 2.3
  - **Details**: Listener: TCP port 1883, forward to ECS target group

- [ ] 6.2.5 Add NLB outputs (DNS name, ARN)
  - **Validates**: Requirements 7.3
  - **Details**: Export NLB DNS name for IoT device connections

## Phase 7: Compute Layer - Lambda Functions

### 7.1 Lambda Module Structure
- [ ] 7.1.1 Create Lambda module structure (modules/lambda/)
  - **Validates**: Requirements 2.5, 2.12, 2.15, 4.2, 4.3, 5.1
  - **Details**: Create main.tf, variables.tf, outputs.tf in modules/lambda/

### 7.2 Lambda_Parsing Function
- [ ] 7.2.1 Create Lambda_Parsing function code
  - **Validates**: Requirements 2.7, 2.8, 2.9, 2.11
  - **Details**: Python 3.11 code to connect to ECS broker as MQTT client, pull messages, parse to JSON format, send to sqs-fifo-distributing

- [ ] 7.2.2 Package Lambda_Parsing deployment artifact
  - **Validates**: Requirements 2.5
  - **Details**: Create ZIP file with function code and dependencies (paho-mqtt, boto3)

- [ ] 7.2.3 Create Lambda_Parsing function resource
  - **Validates**: Requirements 2.5, 2.7
  - **Details**: Function: lambda-tilt-sensor-lab-parsing, runtime: python3.11, memory: 512 MB, timeout: 60s, VPC-enabled (private subnets), environment variables: BROKER_ENDPOINT, MQTT_TOPIC, SQS_QUEUE_URL

- [ ] 7.2.4 Write unit tests for Lambda_Parsing
  - **Validates**: Property 1.1 (Message Ordering)
  - **Details**: Test MQTT message parsing, JSON format validation, SQS message sending

### 7.3 Lambda_Distributing Function
- [ ] 7.3.1 Create Lambda_Distributing function code
  - **Validates**: Requirements 2.12, 2.14
  - **Details**: Python 3.11 code to receive from sqs-fifo-distributing, route messages to sqs-db1 based on business logic

- [ ] 7.3.2 Package Lambda_Distributing deployment artifact
  - **Validates**: Requirements 2.12
  - **Details**: Create ZIP file with function code and dependencies (boto3)

- [ ] 7.3.3 Create Lambda_Distributing function resource
  - **Validates**: Requirements 2.12
  - **Details**: Function: lambda-tilt-sensor-lab-distributing, runtime: python3.11, memory: 256 MB, timeout: 30s, environment variables: SQS_DB1_URL

- [ ] 7.3.4 Create event source mapping for sqs-fifo-distributing
  - **Validates**: Requirements 2.12
  - **Details**: Trigger Lambda_Distributing from sqs-fifo-distributing, batch_size: 10

- [ ] 7.3.5 Write unit tests for Lambda_Distributing
  - **Validates**: Property 1.1 (Message Ordering)
  - **Details**: Test message routing logic, SQS batch processing

### 7.4 Lambda_DB1 Function
- [ ] 7.4.1 Create Lambda_DB1 function code
  - **Validates**: Requirements 2.15
  - **Details**: Python 3.11 code to receive from sqs-db1, persist to Aurora using psycopg2 with connection pooling, handle duplicates via unique constraints

- [ ] 7.4.2 Package Lambda_DB1 deployment artifact
  - **Validates**: Requirements 2.15
  - **Details**: Create ZIP file with function code and dependencies (psycopg2-binary, boto3)

- [ ] 7.4.3 Create Lambda_DB1 function resource
  - **Validates**: Requirements 2.15
  - **Details**: Function: lambda-tilt-sensor-lab-db1, runtime: python3.11, memory: 512 MB, timeout: 120s, VPC-enabled (private subnets), environment variables: DB_HOST, DB_NAME, DB_USER, DB_PASSWORD (from Secrets Manager)

- [ ] 7.4.4 Create event source mapping for sqs-db1
  - **Validates**: Requirements 2.15
  - **Details**: Trigger Lambda_DB1 from sqs-db1, batch_size: 25

- [ ] 7.4.5 Write unit tests for Lambda_DB1
  - **Validates**: Property 1.2 (No Message Loss), Property 1.3 (Idempotency)
  - **Details**: Test database insertion, duplicate handling, connection pooling, error handling

- [ ] 7.4.6 Write property-based test for idempotency
  - **Validates**: Property 1.3 (Idempotency)
  - **Details**: Generate random messages with duplicate (device_id, timestamp), verify single database entry

### 7.5 Lambda_Sync Function
- [ ] 7.5.1 Create Lambda_Sync function code
  - **Validates**: Requirements 5.3
  - **Details**: Python 3.11 code to query Aurora for recent device status and aggregated stats, update Redis cache with appropriate TTL values

- [ ] 7.5.2 Package Lambda_Sync deployment artifact
  - **Validates**: Requirements 5.1
  - **Details**: Create ZIP file with function code and dependencies (psycopg2-binary, redis, boto3)

- [ ] 7.5.3 Create Lambda_Sync function resource
  - **Validates**: Requirements 5.1
  - **Details**: Function: lambda-tilt-sensor-lab-data-transmission, runtime: python3.11, memory: 512 MB, timeout: 120s, VPC-enabled (private subnets), environment variables: DB_HOST, REDIS_HOST

- [ ] 7.5.4 Write unit tests for Lambda_Sync
  - **Validates**: Property 3.1 (Cache Consistency), Property 3.2 (Cache Freshness)
  - **Details**: Test Aurora queries, Redis updates, TTL settings

- [ ] 7.5.5 Write property-based test for cache consistency
  - **Validates**: Property 3.1 (Cache Consistency)
  - **Details**: Update Aurora with random data, trigger sync, verify Redis matches Aurora

### 7.6 Command Handler Functions
- [ ] 7.6.1 Create mqtt-command-handler function code
  - **Validates**: Requirements 4.4
  - **Details**: Python 3.11 code to receive from mqtt-command.fifo, validate command, connect to ECS broker, publish to MQTT topic

- [ ] 7.6.2 Create lorawan-command-handler function code
  - **Validates**: Requirements 4.4
  - **Details**: Python 3.11 code to receive from lorawan-command.fifo, validate command, connect to ECS broker, publish to MQTT topic

- [ ] 7.6.3 Package command handler deployment artifacts
  - **Validates**: Requirements 4.2, 4.3
  - **Details**: Create ZIP files with function code and dependencies (paho-mqtt, boto3)

- [ ] 7.6.4 Create command handler function resources
  - **Validates**: Requirements 4.2, 4.3
  - **Details**: Functions: lambda-tilt-sensor-lab-mqtt-cmd-handler, lambda-tilt-sensor-lab-lorawan-cmd-handler, runtime: python3.11, memory: 256 MB, timeout: 30s, VPC-enabled

- [ ] 7.6.5 Create event source mappings for command queues
  - **Validates**: Requirements 4.2, 4.3
  - **Details**: Trigger handlers from respective FIFO queues

- [ ] 7.6.6 Write unit tests for command handlers
  - **Validates**: Property 2.1 (Command Delivery), Property 2.2 (Command Ordering)
  - **Details**: Test command validation, MQTT publishing, error handling

- [ ] 7.6.7 Write property-based test for command ordering
  - **Validates**: Property 2.2 (Command Ordering)
  - **Details**: Send sequential commands per device, verify broker receipt order

## Phase 8: Application Layer

### 8.1 EC2 Module
- [ ] 8.1.1 Create EC2 module structure (modules/ec2/)
  - **Validates**: Requirements 3.1
  - **Details**: Create main.tf, variables.tf, outputs.tf in modules/ec2/

- [ ] 8.1.2 Create EC2 launch template for Portal API
  - **Validates**: Requirements 3.1
  - **Details**: Launch template: lt-tilt-sensor-lab-portal, instance_type: t3.medium, AMI: Amazon Linux 2023, user_data script to install Node.js/Python API, associate with EC2 Portal security group and IAM role

- [ ] 8.1.3 Create Auto Scaling Group for Portal API
  - **Validates**: Requirements 3.1
  - **Details**: ASG: asg-tilt-sensor-lab-portal, min: 2, max: 4, desired: 2, deployed in private subnets, health check type: ELB

- [ ] 8.1.4 Configure Auto Scaling policies
  - **Validates**: Design scalability requirements
  - **Details**: Target tracking scaling based on CPU utilization (70% target)

### 8.2 ALB Module
- [ ] 8.2.1 Create ALB module structure (modules/alb/)
  - **Validates**: Requirements 3.2
  - **Details**: Create main.tf, variables.tf, outputs.tf in modules/alb/

- [ ] 8.2.2 Create Application Load Balancer
  - **Validates**: Requirements 3.2
  - **Details**: ALB: alb-tilt-sensor-lab-portal, type: application, deployed in public subnets, enable HTTP/2, idle_timeout: 60s

- [ ] 8.2.3 Create ALB target group for EC2
  - **Validates**: Requirements 3.2
  - **Details**: Target group: tg-tilt-sensor-lab-portal, target_type: instance, protocol: HTTP, port: 80, health check on /health endpoint, sticky sessions enabled

- [ ] 8.2.4 Create ALB listeners (HTTP and HTTPS)
  - **Validates**: Requirements 3.2
  - **Details**: HTTP listener (port 80): redirect to HTTPS, HTTPS listener (port 443): forward to EC2 target group, SSL certificate from ACM

- [ ] 8.2.5 Add ALB outputs (DNS name, ARN)
  - **Validates**: Requirements 7.3
  - **Details**: Export ALB DNS name for CloudFront origin

## Phase 9: CDN and Security

### 9.1 CloudFront Module
- [ ] 9.1.1 Create CloudFront module structure (modules/cloudfront/)
  - **Validates**: Requirements 3.6
  - **Details**: Create main.tf, variables.tf, outputs.tf in modules/cloudfront/

- [ ] 9.1.2 Create CloudFront distribution
  - **Validates**: Requirements 3.6, 3.7
  - **Details**: Distribution: cf-tilt-sensor-lab-portal, origin: ALB, HTTPS only (redirect HTTP), custom SSL certificate via ACM, price_class: PriceClass_100, enable HTTP/2 and HTTP/3

- [ ] 9.1.3 Configure CloudFront caching behavior
  - **Validates**: Requirements 3.6
  - **Details**: Cache static assets, forward headers for dynamic content, compress objects

- [ ] 9.1.4 Associate WAF Web ACL with CloudFront
  - **Validates**: Requirements 3.6
  - **Details**: Attach waf-tilt-sensor-lab-portal to CloudFront distribution

- [ ] 9.1.5 Add CloudFront outputs (domain name, distribution ID)
  - **Validates**: Requirements 7.3
  - **Details**: Export CloudFront domain name for end-user access

## Phase 10: Database Schema and Initialization

### 10.1 Database Schema
- [ ] 10.1.1 Create SQL schema file for Aurora
  - **Validates**: Requirements 3.3
  - **Details**: Create schema.sql with sensor_data table (id, device_id, timestamp, tilt_angle, status, battery_level, created_at), device_status table (device_id, last_seen, current_status, updated_at), indexes, unique constraints

- [ ] 10.1.2 Create database initialization script
  - **Validates**: Requirements 3.3
  - **Details**: Create init_db.sh script to connect to Aurora and execute schema.sql

- [ ] 10.1.3 Document database connection procedure
  - **Validates**: Design post-deployment steps
  - **Details**: Add instructions to README for connecting to Aurora via bastion host or SSM Session Manager

## Phase 11: Integration and Testing

### 11.1 Integration Tests
- [ ] 11.1.1 Write integration test for ingestion pipeline
  - **Validates**: Property 1.2 (No Message Loss), Property 6.1 (Processing Latency)
  - **Details**: Send test message to ECS broker, trigger Lambda_Parsing, verify message flows through sqs-fifo-distributing -> Lambda_Distributing -> sqs-db1 -> Lambda_DB1 -> Aurora

- [ ] 11.1.2 Write integration test for command flow
  - **Validates**: Property 2.1 (Command Delivery)
  - **Details**: Send command to mqtt-command.fifo, verify command handler processes and forwards to broker

- [ ] 11.1.3 Write integration test for sync flow
  - **Validates**: Property 3.1 (Cache Consistency)
  - **Details**: Insert data in Aurora, trigger Lambda_Sync, verify data in Redis

### 11.2 Property-Based Tests
- [ ] 11.2.1 Write PBT for message ordering preservation
  - **Validates**: Property 1.1 (Message Ordering Preservation)
  - **Details**: Generate random message sequences per device with timestamps, send through pipeline, verify database ordering matches input

- [ ] 11.2.2 Write PBT for no message loss
  - **Validates**: Property 1.2 (No Message Loss)
  - **Details**: Send N random messages, verify count(Aurora) + count(DLQ) = N

- [ ] 11.2.3 Write PBT for processing latency
  - **Validates**: Property 6.1 (Processing Latency)
  - **Details**: Send messages with timestamps, measure end-to-end latency from broker to Aurora, verify < 10 minutes

### 11.3 Security Tests
- [ ] 11.3.1 Test network isolation
  - **Validates**: Property 4.1 (Network Isolation)
  - **Details**: Attempt to connect to Aurora, Redis, ECS from external IP, verify all connections fail

- [ ] 11.3.2 Test IAM least privilege
  - **Validates**: Property 4.2 (Least Privilege IAM)
  - **Details**: Review IAM policies, attempt unauthorized actions (e.g., Lambda_Parsing accessing RDS), verify denials

- [ ] 11.3.3 Test WAF rules
  - **Validates**: Requirements 3.6
  - **Details**: Send malicious requests (SQL injection, XSS), verify WAF blocks them, test rate limiting

## Phase 12: Documentation and Deployment

### 12.1 Documentation
- [ ] 12.1.1 Create comprehensive README.md
  - **Validates**: Design deployment strategy
  - **Details**: Document prerequisites, deployment phases, post-deployment steps, testing procedures, troubleshooting

- [ ] 12.1.2 Document Terraform module usage
  - **Validates**: Requirements 7.1
  - **Details**: Add README.md to each module with inputs, outputs, usage examples

- [ ] 12.1.3 Create operational runbook
  - **Validates**: Design operational procedures
  - **Details**: Document daily checks, troubleshooting procedures, scaling procedures, disaster recovery

### 12.2 Deployment Validation
- [ ] 12.2.1 Validate Terraform configuration
  - **Validates**: Requirements 7.1, 7.2, 7.3
  - **Details**: Run terraform fmt, terraform validate, terraform plan, verify no errors

- [ ] 12.2.2 Execute phased Terraform deployment
  - **Validates**: Design deployment strategy
  - **Details**: Deploy in phases (Foundation -> Security -> Storage -> Messaging -> Compute -> Application -> CDN), verify each phase before proceeding

- [ ] 12.2.3 Verify all resources created with correct naming
  - **Validates**: Terraform naming conventions
  - **Details**: Check all resources follow naming patterns (service-project-app-env-purpose), verify mandatory tags applied

- [ ] 12.2.4 Execute post-deployment steps
  - **Validates**: Design post-deployment steps
  - **Details**: Initialize database schema, deploy Lambda code, push ECS container image, configure SSL certificates, set up DNS

- [ ] 12.2.5 Execute end-to-end system test
  - **Validates**: All requirements
  - **Details**: Test IoT device connectivity, send test messages through pipeline, verify data in Aurora and Redis, test web portal access, test command and control

---

**Total Tasks**: 120+
**Estimated Effort**: 4-6 weeks for full implementation
**Priority**: Execute phases sequentially (1 -> 12)
