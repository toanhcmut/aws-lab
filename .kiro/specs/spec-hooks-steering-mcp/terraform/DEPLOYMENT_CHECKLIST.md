# Deployment Checklist

Use this checklist to ensure a successful deployment of the 3-tier AWS architecture.

## Pre-Deployment

### AWS Account Setup
- [ ] AWS account created and accessible
- [ ] AWS CLI installed and configured
- [ ] IAM user/role has required permissions (VPC, EC2, ELB, RDS, Auto Scaling)
- [ ] Target region has at least 3 Availability Zones
- [ ] Service quotas checked (VPCs, NAT Gateways, RDS instances)

### Terraform Setup
- [ ] Terraform >= 1.0 installed
- [ ] Terraform configuration files reviewed
- [ ] `terraform.tfvars` created from example
- [ ] AMI ID updated for target region
- [ ] Database credentials configured (strong password)
- [ ] Project naming variables customized

### Configuration Review
- [ ] VPC CIDR block doesn't conflict with existing networks
- [ ] Instance types appropriate for workload
- [ ] ASG capacity values set correctly (min ≤ desired ≤ max)
- [ ] Database engine and version selected
- [ ] Backup retention period configured
- [ ] Health check settings reviewed

## Deployment Steps

### Initialize
- [ ] Run `terraform init`
- [ ] Verify module download successful
- [ ] Verify provider installation successful

### Validate
- [ ] Run `terraform validate`
- [ ] Configuration validation passed
- [ ] No syntax errors

### Plan
- [ ] Run `terraform plan`
- [ ] Review resources to be created (~30-40 resources)
- [ ] Verify resource names follow naming convention
- [ ] Verify tags are correct
- [ ] Check estimated costs

### Apply
- [ ] Run `terraform apply`
- [ ] Review plan one more time
- [ ] Type `yes` to confirm
- [ ] Wait for completion (typically 10-15 minutes)
- [ ] Note any errors or warnings

## Post-Deployment

### Verification
- [ ] All resources created successfully
- [ ] VPC and subnets created
- [ ] NAT Gateways operational
- [ ] ALB created and healthy
- [ ] Target group created
- [ ] ASG created with desired capacity
- [ ] EC2 instances launched and healthy
- [ ] RDS instance created and available
- [ ] RDS Multi-AZ standby created

### Outputs
- [ ] Run `terraform output` to view all outputs
- [ ] Save ALB DNS name
- [ ] Save RDS endpoint
- [ ] Save VPC ID and subnet IDs
- [ ] Document security group IDs

### Testing
- [ ] Access ALB DNS name in browser
- [ ] Verify web server responds (if user data configured)
- [ ] Check ALB target health in AWS Console
- [ ] Verify EC2 instances are healthy
- [ ] Test RDS connectivity from EC2 instance
- [ ] Verify Multi-AZ configuration in RDS console

### Security Review
- [ ] Review security group rules
- [ ] Verify ALB only accepts traffic on ports 80/443
- [ ] Verify EC2 only accepts traffic from ALB
- [ ] Verify RDS only accepts traffic from EC2
- [ ] Check that RDS is not publicly accessible
- [ ] Verify encryption enabled on RDS

### Monitoring Setup
- [ ] Enable CloudWatch monitoring
- [ ] Set up CloudWatch alarms for:
  - [ ] ALB unhealthy targets
  - [ ] ASG scaling events
  - [ ] RDS CPU utilization
  - [ ] RDS storage space
  - [ ] RDS connection count
- [ ] Configure SNS notifications

### Documentation
- [ ] Document ALB DNS name
- [ ] Document RDS endpoint
- [ ] Document any custom configurations
- [ ] Update runbook with deployment details
- [ ] Share access information with team

## Production Readiness (if applicable)

### Configuration Changes
- [ ] Set `db_skip_final_snapshot = false`
- [ ] Enable RDS deletion protection
- [ ] Increase instance types for production workload
- [ ] Adjust ASG capacity for production traffic
- [ ] Configure SSL/TLS certificate for ALB
- [ ] Set up Route53 DNS records
- [ ] Configure backup strategy

### Security Hardening
- [ ] Move database credentials to AWS Secrets Manager
- [ ] Enable AWS WAF on ALB
- [ ] Configure VPC Flow Logs
- [ ] Enable CloudTrail logging
- [ ] Set up AWS Config rules
- [ ] Review and restrict IAM permissions
- [ ] Enable MFA for AWS accounts

### High Availability
- [ ] Verify Multi-AZ RDS configuration
- [ ] Test AZ failure scenario
- [ ] Verify ASG auto-healing
- [ ] Test ALB health checks
- [ ] Document RTO and RPO

### Backup and Recovery
- [ ] Verify RDS automated backups
- [ ] Test RDS snapshot restore
- [ ] Document backup retention policy
- [ ] Create disaster recovery plan
- [ ] Test recovery procedures

### Cost Optimization
- [ ] Review resource utilization
- [ ] Set up AWS Cost Explorer
- [ ] Configure billing alerts
- [ ] Review Reserved Instance opportunities
- [ ] Consider Savings Plans

## Maintenance

### Regular Tasks
- [ ] Review CloudWatch metrics weekly
- [ ] Check for AWS service updates
- [ ] Update AMIs monthly
- [ ] Review security group rules monthly
- [ ] Test backup restoration quarterly
- [ ] Review and update documentation

### Terraform State
- [ ] Set up remote state backend (S3 + DynamoDB)
- [ ] Enable state file versioning
- [ ] Configure state locking
- [ ] Back up state file regularly
- [ ] Document state file location

## Troubleshooting

### Common Issues Checklist
- [ ] If deployment fails, check AWS service quotas
- [ ] If RDS creation fails, verify password requirements
- [ ] If instances unhealthy, check security groups
- [ ] If ALB not accessible, verify internet gateway
- [ ] If NAT Gateway issues, check Elastic IP limits

### Rollback Plan
- [ ] Document rollback procedure
- [ ] Test `terraform destroy` in non-production
- [ ] Ensure backups before major changes
- [ ] Have previous Terraform state backed up

## Sign-Off

- [ ] Deployment completed successfully
- [ ] All verification steps passed
- [ ] Documentation updated
- [ ] Team notified
- [ ] Monitoring configured
- [ ] Backup verified

**Deployed by:** _______________  
**Date:** _______________  
**Environment:** _______________  
**Terraform Version:** _______________  
**AWS Region:** _______________

## Notes

Use this space to document any issues, customizations, or important information:

```
[Add your notes here]
```
