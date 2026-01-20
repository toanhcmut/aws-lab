# IoT Tilt Sensor Monitoring System - Terraform Infrastructure

This repository contains the Terraform infrastructure code for the IoT Tilt Sensor Monitoring System on AWS.

## Architecture Overview

The system implements a scheduled batch processing architecture that:
- Collects sensor data every 5 minutes from IoT devices
- Processes data through a multi-stage Lambda pipeline
- Stores data in Aurora PostgreSQL with Redis caching
- Serves data via a web portal with CloudFront CDN

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate credentials
- AWS account with necessary permissions
- S3 bucket and DynamoDB table for Terraform state (optional but recommended)

## Project Structure

```
terraform/
├── main.tf                 # Root module orchestration
├── variables.tf            # Input variables
├── outputs.tf              # Output values
├── versions.tf             # Provider versions and backend config
├── terraform.tfvars        # Variable values
├── README.md               # This file
└── modules/
    ├── vpc/                # VPC and networking
    ├── nlb/                # Network Load Balancer
    ├── ecs/                # ECS Fargate for message broker
    ├── lambda/             # Lambda functions
    ├── sqs/                # SQS queues
    ├── rds/                # Aurora PostgreSQL
    ├── elasticache/        # Redis cluster
    ├── ec2/                # EC2 Portal API
    ├── alb/                # Application Load Balancer
    ├── cloudfront/         # CloudFront distribution
    ├── waf/                # AWS WAF
    ├── eventbridge/        # EventBridge rules
    └── iam/                # IAM roles and policies
```

## Naming Conventions

All resources follow the project naming schema:

### Standard Resources (S3, EC2, RDS, VPC, etc.)
Pattern: `[service]-[project]-[app]-[env]-[purpose]`
Example: `vpc-tilt-sensor-lab`

### Hierarchical Services (Parameter Store / Secrets Manager)
Pattern: `[service]/[project]/[app]/[env]/[purpose]`
Example: `ssm/tilt/sensor/lab/db_password`

### CloudWatch Log Groups
Pattern: `/[provider]/[service]/[project]/[app]/[env]/[purpose]`
Example: `/aws/lambda/tilt/sensor/lab/parsing`

## Deployment

### 1. Initialize Terraform

```bash
cd terraform
terraform init
```

### 2. Configure Backend (Optional but Recommended)

Create an S3 bucket and DynamoDB table for state management:

```bash
# Create S3 bucket for state
aws s3 mb s3://s3-tilt-sensor-lab-tfstate --region us-east-1

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name dynamodb-tilt-sensor-lab-tfstate-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

Then uncomment the backend configuration in `versions.tf`.

### 3. Review and Customize Variables

Edit `terraform.tfvars` to customize the deployment:

```hcl
project = "tilt"
app     = "sensor"
env     = "lab"
region  = "us-east-1"

vpc_cidr = "10.0.0.0/16"
# ... other variables
```

### 4. Validate Configuration

```bash
terraform fmt -recursive
terraform validate
```

### 5. Plan Deployment

```bash
terraform plan -out=tfplan
```

### 6. Phased Deployment (Recommended)

Deploy in phases to ensure dependencies are met:

#### Phase 1: Foundation (Network)
```bash
terraform apply -target=module.vpc
```

#### Phase 2: Security
```bash
terraform apply -target=module.iam -target=module.waf
```

#### Phase 3: Storage Layer
```bash
terraform apply -target=module.rds -target=module.elasticache
```

#### Phase 4: Messaging Layer
```bash
terraform apply -target=module.sqs -target=module.eventbridge
```

#### Phase 5: Compute Layer
```bash
terraform apply -target=module.ecs -target=module.lambda
```

#### Phase 6: Load Balancers
```bash
terraform apply -target=module.nlb -target=module.alb
```

#### Phase 7: Application Layer
```bash
terraform apply -target=module.ec2
```

#### Phase 8: CDN and Security
```bash
terraform apply -target=module.cloudfront
```

#### Phase 9: Full Deployment
```bash
terraform apply
```

### 7. Single-Step Deployment (Alternative)

```bash
terraform apply tfplan
```

## Post-Deployment Steps

After Terraform deployment, complete these manual steps:

### 1. Database Initialization

Connect to Aurora and run schema creation:

```bash
# Connect via bastion or SSM Session Manager
psql -h <aurora-endpoint> -U postgres -d tilt_sensor

# Run schema.sql
\i schema.sql
```

### 2. Lambda Function Code

Package and deploy Lambda function code:

```bash
# For each Lambda function
cd lambda-functions/parsing
zip -r function.zip .
aws lambda update-function-code \
  --function-name lambda-tilt-sensor-lab-parsing \
  --zip-file fileb://function.zip
```

### 3. ECS Container Image

Build and push message broker image:

```bash
# Build Docker image
docker build -t tilt-sensor-broker .

# Tag and push to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
docker tag tilt-sensor-broker:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/tilt-sensor-broker:latest
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/tilt-sensor-broker:latest
```

### 4. SSL Certificate

Request and validate ACM certificate:

```bash
aws acm request-certificate \
  --domain-name portal.example.com \
  --validation-method DNS \
  --region us-east-1
```

### 5. DNS Configuration

Point your domain to CloudFront:

```bash
# Get CloudFront domain name
terraform output cloudfront_domain_name

# Create Route 53 A record (alias) pointing to CloudFront
```

## Outputs

After deployment, retrieve important outputs:

```bash
# All outputs
terraform output

# Specific output
terraform output nlb_dns_name
terraform output cloudfront_domain_name
```

## Testing

### Validate Terraform Configuration

```bash
terraform fmt -check -recursive
terraform validate
terraform plan
```

### Test IoT Device Connectivity

```bash
# Get NLB DNS name
NLB_DNS=$(terraform output -raw nlb_dns_name)

# Test MQTT connection
mosquitto_pub -h $NLB_DNS -p 1883 -t "sensors/test" -m '{"device_id":"test-001","tilt_angle":15.5}'
```

### Test Web Portal

```bash
# Get CloudFront domain
CF_DOMAIN=$(terraform output -raw cloudfront_domain_name)

# Test HTTPS access
curl -I https://$CF_DOMAIN
```

## Maintenance

### Update Infrastructure

```bash
# Make changes to .tf files
terraform plan
terraform apply
```

### Destroy Infrastructure

```bash
# Destroy all resources (WARNING: This will delete everything!)
terraform destroy

# Destroy specific module
terraform destroy -target=module.ec2
```

## Cost Estimation

Estimated monthly cost: $340-470

Major cost components:
- ECS Fargate: $30-40
- EC2 instances: $60-70
- Aurora Serverless: $40-80
- ElastiCache Redis: $25-30
- CloudFront: $85-100
- Load Balancers: $40-50
- Lambda: $5-10
- NAT Gateway: $30-40 (if enabled)

## Troubleshooting

### Common Issues

1. **Terraform Init Fails**
   - Ensure AWS credentials are configured
   - Check internet connectivity
   - Verify Terraform version

2. **Module Dependencies**
   - Use phased deployment approach
   - Check module outputs are correctly referenced

3. **Resource Limits**
   - Check AWS service quotas
   - Request limit increases if needed

4. **State Lock Issues**
   - Ensure DynamoDB table exists
   - Check for stale locks: `terraform force-unlock <lock-id>`

## Security Best Practices

- Never commit `terraform.tfstate` to version control
- Use S3 backend with encryption for state storage
- Enable MFA for AWS console access
- Rotate IAM credentials regularly
- Review security group rules periodically
- Enable CloudTrail for audit logging

## Support

For issues or questions:
1. Check the module README files
2. Review AWS documentation
3. Check Terraform AWS provider documentation
4. Contact the DevOps team

## License

Internal use only - TiltSensor Project
