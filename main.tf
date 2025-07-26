terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket  = "rsschool-devops-terraform-state-ab"
    region  = "eu-central-1"
    key     = "state/terraform.tfstate"
    encrypt = true
  }
}

provider "aws" {
  region = var.region
}

resource "aws_iam_role" "github_actions_role" {
  name = "GithubActionsRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::108782051436:oidc-provider/token.actions.githubusercontent.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" : "repo:tosigaeva/rsschool-devops-course-tasks:*"
          },
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_policies" {
  for_each = toset([
    "AmazonEC2FullAccess",
    "AmazonRoute53FullAccess",
    "AmazonS3FullAccess",
    "IAMFullAccess",
    "AmazonVPCFullAccess",
    "AmazonSQSFullAccess",
    "AmazonEventBridgeFullAccess",
    "AmazonEC2ContainerRegistryFullAccess"
  ])

  role       = aws_iam_role.github_actions_role.name
  policy_arn = "arn:aws:iam::aws:policy/${each.value}"
}

# ECR Repository for Flask App
resource "aws_ecr_repository" "flask_app" {
  name                 = "flask-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "Flask App Repository"
  }
}

# ECR Lifecycle Policy
resource "aws_ecr_lifecycle_policy" "flask_app" {
  repository = aws_ecr_repository.flask_app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Output the private key for SSH access
output "private_key_pem" {
  value     = tls_private_key.my_key.private_key_pem
  sensitive = true
}

# Output instance information
output "bastion_host_public_ip" {
  value = aws_instance.bastion_host.public_ip
}

output "control_node_public_ip" {
  value = aws_instance.control_node.public_ip
}

output "agent_node_private_ip" {
  value = aws_instance.agent_node.private_ip
}
