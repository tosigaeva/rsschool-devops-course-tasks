# Terraform AWS Infrastructure

## Overview
This repository contains Terraform code to manage AWS resources using GitHub Actions for CI/CD.

## Setup
1. Create an IAM user with MFA and necessary permissions.
2. Set up GitHub Secrets for AWS credentials:
   - `AWS_ROLE_ARN`: The ARN of the IAM role.
   - `AWS_REGION`: The AWS region where resources are deployed.
3. Configure the workflow to trigger on push or pull request to the main branch.

## Running the Workflow
The GitHub Actions workflow runs the following:
- **Check**: Checks Terraform formatting.
- **Plan**: Plans the deployment.
- **Apply**: Applies the Terraform changes if on the main branch.

## Verification
To verify the setup:
1. Execute Terraform plans to ensure they run successfully.

## Task 2: Basic Infrastructure Configuration

Terraform code to configure the basic networking infrastructure required for a Kubernetes (K8s) cluster.

1. Created Terraform code to configure the following:

- VPC (virtual private cloud) in eu-central-1 zone
- 2 public subnets in different AZs
- 2 private subnets in different AZs
- Internet Gateway
- Routing configuration:
  - Instances in all subnets can reach each other
  - Instances in public subnets can reach addresses outside VPC and vice-versa
- Security Groups and Network ACLs for the VPC and subnets
- NAT for private subnets, so instances in private subnet can connect with outside world. In the task, creating one NAT Gateway for practice is enough, but in production, we should create NAT for every subnet.

2. Set up a GitHub Actions (GHA) pipeline for the Terraform code.