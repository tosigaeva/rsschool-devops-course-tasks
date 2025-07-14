variable "bucket_name" {
  type        = string
  description = "S3 bucket to store the Terraform state"
  default     = "rsschool-devops-terraform-state-ab"
}

variable "region" {
  type        = string
  description = "AWS region where S3 bucket is located"
  default     = "eu-central-1"
}

variable "instance_type" {
  default = "t3.medium"
}

variable "azs" {
  type        = list(string)
  description = "Availability Zones"
  default     = ["eu-central-1a", "eu-central-1b"]
}

variable "public_subnets" {
  type        = list(string)
  description = "Public Subnet CIDR values"
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}
variable "private_subnets" {
  type        = list(string)
  description = "Private Subnet CIDR values"
  default     = ["10.0.2.0/24", "10.0.3.0/24"]
}
