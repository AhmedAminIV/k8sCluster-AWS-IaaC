# Define inputs required from the root module configuration

variable "vpc_id" {
  description = "The ID of the VPC where resources will be deployed."
  type        = string
}

variable "vpc_cidr_block" {
  description = "The VPC CIDR block (e.g., 10.0.0.0/16) used to define security group ingress rules for internal communication."
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for worker and master nodes."
  type        = list(string)
}

variable "public_subnet_id" {
  description = "ID of the single public subnet for the bastion host."
  type        = string
}

variable "aws_region" {
  description = "The AWS region where resources are deployed (e.g., eu-west-1)."
  type        = string
}

variable "key_name" {
  description = "The name of the key pair to use for EC2 instances."
  type        = string
}
