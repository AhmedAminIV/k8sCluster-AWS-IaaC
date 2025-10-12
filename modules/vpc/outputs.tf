# modules/vpc/output.tf (Module)

# Output the ID of the created VPC
output "vpc_id" {
  description = "The ID of the VPC."
  value       = aws_vpc.main.id
}

# Output the CIDR block used
output "vpc_cidr_block_used" {
  description = "The CIDR block used for the VPC."
  value       = aws_vpc.main.cidr_block
}

# Public Subnets
output "public_subnet_id" {
  description = "The ID of the single public subnet (for Bastion/NAT GW)."
  value       = aws_subnet.public.id
}

# Private Subnets
output "private_subnet_ids" {
  description = "List of IDs for the three private subnets."
  # Use the values attribute of the map created by for_each to get a list of IDs
  value = values(aws_subnet.private)[*].id
}

# Network Components
output "internet_gateway_id" {
  description = "The ID of the Internet Gateway."
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_id" {
  description = "The ID of the NAT Gateway."
  value       = aws_nat_gateway.main.id
}