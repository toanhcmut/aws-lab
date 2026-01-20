# Requirements Document: IoT Tilt Sensor Monitoring System

## 1. Introduction

This document specifies the requirements for an IoT Tilt Sensor Monitoring System infrastructure on AWS. The system handles sensor data ingestion via a scheduled batch processing pipeline, provides command and control capabilities, and serves data through a web portal. The infrastructure is designed for high availability, security, and scalability using AWS managed services orchestrated via Terraform.

## 2. Glossary

- **System**: The complete IoT Tilt Sensor Monitoring System infrastructure.
- **Message_Broker**: The message broker service running on ECS Fargate that acts as the initial buffer for IoT device connections.
- **Ingestion_Pipeline**: The chain of Lambda functions and SQS queues that process data from the broker to the database.
- **Parsing_Function**: AWS Lambda function that pulls and parses data from the Message Broker.
- **Distributing_Function**: AWS Lambda function that routes parsed messages.
- **DB_Worker_Function**: AWS Lambda function that persists data to Aurora.
- **Portal_API**: The backend API service running on EC2.
- **Network_Infrastructure**: VPC, subnets, gateways, and routing components.

## 3. Requirements

### 3.1 Network Infrastructure

**User Story**: As a system architect, I want a secure multi-tier network architecture, so that I can isolate public-facing and internal resources while maintaining high availability.

**Acceptance Criteria**:

1.1. THE Network_Infrastructure SHALL create a VPC with public and private subnets across 2 availability zones.

1.2. THE Network_Infrastructure SHALL provision an Internet Gateway attached to the VPC for public subnet internet access.


### 3.2 IoT Data Ingestion & Processing Pipeline

**User Story**: As an IoT platform operator, I want a scheduled batch processing mechanism that collects data every 5 minutes, so that I can optimize compute costs and ensure data is processed in the correct order before storage.

**Acceptance Criteria**:

**Infrastructure Provisioning**:

2.1. THE System SHALL provision a Network Load Balancer (NLB) in public subnets listening on TCP ports to accept connections from IoT devices.

2.2. THE System SHALL provision an Amazon ECS Cluster (Fargate) in private subnets to host the Message_Broker.

2.3. THE System SHALL ensure the NLB forwards raw IoT traffic to the Message_Broker tasks on ECS.

**Step 1: Scheduled Trigger**:

2.4. THE System SHALL provision an EventBridge Rule configured to trigger every 5 minutes.

2.5. THE System SHALL provision a Lambda function named Lambda_Parsing (Parsing Function).

2.6. WHEN the EventBridge Rule fires, IT SHALL trigger the Lambda_Parsing function.

**Step 2: Data Ingestion (Pull Model)**:

2.7. THE Lambda_Parsing SHALL be configured with network access to connect to the Message_Broker on ECS.

2.8. WHEN triggered, Lambda_Parsing SHALL act as a persistent MQTT client to pull retained/buffered messages from the Message_Broker.

2.9. THE Lambda_Parsing SHALL parse raw MQTT data into the system's standard JSON format.

**Step 3: Distribution & Ordering**:

2.10. THE System SHALL provision an SQS FIFO queue named sqs-fifo-distributing to ensure strict message ordering (e.g., Alarms processed before Normal status).

2.11. THE Lambda_Parsing SHALL publish the parsed JSON data to sqs-fifo-distributing.

2.12. THE System SHALL provision a Lambda function named Lambda_Distributing triggered by sqs-fifo-distributing.

**Step 4: Routing & Storage Buffer**:

2.13. THE System SHALL provision a standard SQS queue named sqs-db1 acting as a storage buffer to prevent database throttling.

2.14. THE Lambda_Distributing SHALL route appropriate data payloads to sqs-db1.

**Step 5: Persistence**:

2.15. THE System SHALL provision a Lambda function named Lambda_DB1 triggered by sqs-db1.

2.16. Here is the flow IoT Devices $\rightarrow$ Network Load Balancer (Public Subnet) $\rightarrow$ Message_Broker (ECS Fargate/Private Subnet)

Lambda_Parsing $\xrightarrow{\text{Pull Data}}$ Message_Broker (ECS)Lambda_Parsing $\rightarrow$ SQS FIFO (sqs-fifo-distributing) $\rightarrow$ Lambda_Distributing $\rightarrow$ SQS Standard (sqs-db1) $\rightarrow$ Lambda_DB1

### 3.3 Application Backend and Storage Layer

**User Story**: As a web application developer, I want a secure backend API with database and caching capabilities, so that I can serve portal requests efficiently, securely, and at scale.

**Acceptance Criteria**:

3.1. THE System SHALL provision EC2 instances in private subnets to host the Portal_API.

3.2. THE System SHALL provision an Application Load Balancer (ALB) in public subnets to distribute traffic across to the EC2 instances.

3.3. THE Storage_Layer SHALL provision an Amazon Aurora PostgreSQL cluster in private subnets for persistent data storage.

3.4. THE Storage_Layer SHALL provision an ElastiCache Redis cluster in private subnets for application caching.

3.5. THE Portal_API EC2 instances SHALL connect to both Aurora and Redis for data operations.

3.6. THE Security_Layer SHALL provision a CloudFront distribution with AWS WAF Web ACL attached.

3.7. WHEN requests arrive at CloudFront, THE System SHALL route them to the Application Load Balancer origin.

### 3.4 Command and Control Messaging

**User Story**: As a device operator, I want to send commands to IoT devices through reliable message queues, so that I can control device behavior remotely.

**Acceptance Criteria**:

4.1. THE System SHALL create two SQS FIFO queues named mqtt-command.fifo and lorawan-command.fifo.

4.2. THE System SHALL provision a Lambda function named mqtt-command-handler triggered by the mqtt-command.fifo queue.

4.3. THE System SHALL provision a Lambda function named lorawan-command-handler triggered by the lorawan-command.fifo queue.

4.4. WHEN messages arrive in these queues, the respective Command_Handler SHALL process them and forward commands to the Message_Broker.

4.5 Here is the flow: EC2 -> mqtt-command.fifo / lorawan-command.fifo -> mqtt-command.fifo queue / lorawan-command.fifo queue -> Message_Broker 

### 3.5 Data Synchronization

**User Story**: As a system administrator, I want automated data synchronization between the database and cache, so that the application serves fresh data without manual intervention.

**Acceptance Criteria**:

5.1. THE System SHALL provision a Lambda function named data-transmission.

5.2. THE System SHALL create an EventBridge rule that triggers this function every 5 minutes (separate from the Ingestion trigger).

5.3. THE function SHALL synchronize necessary data from Aurora to Redis.

### 3.6 Security and Access Control

**User Story**: As a security engineer, I want least-privilege IAM policies and network segmentation, so that I can minimize the attack surface.

**Acceptance Criteria**:

6.1. THE Security_Layer SHALL create IAM roles for all Lambda functions (Lambda_Parsing, Lambda_Distributing, Lambda_DB1) with only necessary permissions (e.g., sqs:SendMessage, rds-db:connect).

6.2. THE Security_Layer SHALL create Security Groups allowing:
   - Lambda_Parsing to access ECS (MQTT Broker).
   - Lambda_DB1 to access Aurora Database.

6.3. THE Security_Layer SHALL ensure private subnet resources cannot receive direct inbound traffic from the internet.

### 3.7 Infrastructure as Code Modularity

**User Story**: As a DevOps engineer, I want modular and reusable Terraform code, so that I can maintain and scale the infrastructure efficiently.

**Acceptance Criteria**:

7.1. THE System SHALL organize Terraform code into separate modules (vpc, ecs, rds, lambda, sqs).

7.2. THE System SHALL define configurable variables for region, CIDR blocks, and schedule intervals (e.g., ingestion_schedule_expression = "rate(5 minutes)").

7.3. THE System SHALL use Terraform outputs to expose resource identifiers for cross-module references.

---

**Document Version**: 1.0  
**Last Updated**: 2026-01-18  
**Status**: Approved