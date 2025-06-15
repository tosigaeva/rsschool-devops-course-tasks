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
