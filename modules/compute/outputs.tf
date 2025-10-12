# Export the Bastion Host's Public IP for external connection
output "bastion_public_ip" {
  description = "The public IP address of the Bastion Host."
  value       = aws_instance.bastion.public_ip
}

# Export the Bastion Host's Private IP for connecting to private nodes
output "bastion_private_ip" {
  description = "The private IP address of the Bastion Host."
  value       = aws_instance.bastion.private_ip
}

# Export the Master Node's Private IP
output "master_private_ip" {
  description = "The private IP address of the Master Node."
  value       = aws_instance.master.private_ip
}

# Export the Private IPs of the Worker Nodes
output "worker_private_ips" {
  description = "List of private IP addresses for the Worker Nodes."
  value       = values(aws_instance.workers)[*].private_ip
}

# Export the ID of the Compute Security Group, useful for further resource security
output "compute_security_group_id" {
  description = "The ID of the Security Group shared by Master and Worker Nodes."
  value       = aws_security_group.compute_sg.id
}
