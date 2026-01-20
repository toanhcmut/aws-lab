terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend configuration for state management
  backend "s3" {
    # bucket         = "s3-tilt-sensor-lab-tfstate"
    # key            = "terraform.tfstate"
    # region         = "us-east-1"
    # dynamodb_table = "dynamodb-tilt-sensor-lab-tfstate-lock"
    # encrypt        = true
    
    # Uncomment and configure the above after creating the S3 bucket and DynamoDB table
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = var.common_tags
  }
}
