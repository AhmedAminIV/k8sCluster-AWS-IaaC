# Root Variables: Input values for the overall configuration

variable "aws_region" {
  description = "The AWS Region to provision the resources"
  type = string
  default = "eu-west-1"
}

variable "vpc_cidr_block" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "environment" {
  description = "The environment name (e.g., 'dev', 'prod')."
  type        = string
  default     = "dev"
}

variable "name_prefix" {
  description = "A prefix for all resource names."
  type        = string
  default     = "k8s"
}
