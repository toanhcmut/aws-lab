---
inclusion: always
---
---
inclusion: always
---
# Terraform Development Rules

## 1. File Structure
* **Modularization:** DO NOT put all code in one file. Split into:
  * `main.tf`: Core resource logic.
  * `variables.tf`: Input variable definitions.
  * `outputs.tf`: Useful output values.
  * `versions.tf`: Provider constraints.

## 2. Naming Conventions (Strict)
All resources must follow the project naming schema:
* **Components:**
  * `project`: "tilt" (or "smartbuddy" based on context)
  * `app`: "sensor" (or "shared" if applicable)
  * `env`: "lab" (or "dev"/"prod")

* **Rule 1: Standard Resources (S3, EC2, RDS, VPC, etc.)**
  * Pattern: `[service]-[project]-[app]-[env]-[purpose]`
  * Example: `s3-tilt-sensor-lab-data`

* **Rule 2: Hierarchical Services (Parameter Store / Secrets Manager)**
  * Pattern: `[service]/[project]/[app]/[env]/[purpose]`
  * Use forward slashes `/` as separators.
  * Example: `ssm/tilt/sensor/lab/db_password`

* **Rule 3: CloudWatch Log Groups**
  * Pattern: `/[provider]/[service]/[project]/[app]/[env]/[purpose]`
  * Must start with a slash `/`.
  * Example: `/aws/lambda/tilt/sensor/lab/error_logs`

## 3. Security & Best Practices
* **No Hardcoded Secrets:** NEVER put Access Keys/Secret Keys in `.tf` files.
* **Least Privilege:** Avoid `Action: "*"` in IAM roles.
* **Versioning:** Pin AWS Provider version (e.g., `~> 5.0`).

## 4. Mandatory Tags
* Apply these `tags` to ALL resources:
  * `Project`: "KiroDemo"
  * `Environment`: "Lab"
  * `CreatedBy`: "Toan-Tran"
  * `ManagedBy`: "Terraform"

## 5. Module Strategy (High Priority)
* **Prefer Registry Modules:** ALWAYS prioritize using official or verified community modules (e.g., from `terraform-aws-modules` on Terraform Registry) for complex infrastructure components such as VPC, EKS, RDS, and ALB.
* **Custom Logic:** Only write custom `resource` blocks if the available modules do not support specific project requirements or if the resource is simple/standalone (e.g., a single S3 bucket or SSM parameter).
* **Module Source:** Use versioned sources (e.g., `version = "~> 5.0"`).