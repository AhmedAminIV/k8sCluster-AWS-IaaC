# modules/vpc/variables.tf (Module)

variable "vpc_cidr_block" {
  description = "The CIDR block for the VPC."
  type        = string
}

variable "environment" {
  description = "The environment tag (e.g., dev, prod)."
  type        = string
}

variable "name_prefix" {
  description = "A prefix used for naming resources."
  type        = string
}

variable "aws_region" {
  description = "The AWS region to use for AZ calculation."
  type        = string
  default     = "eu-west-1" # Default must match root or be passed from root
}
