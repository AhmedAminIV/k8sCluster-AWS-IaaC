# --- 1. SECURE SSH KEY MANAGEMENT ---

# Resource 1: Generate a local private key
# The key will be securely stored in AWS Secrets Manager.
resource "tls_private_key" "cluster_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Resource 2: Register the public key with AWS EC2
resource "aws_key_pair" "cluster_key" {
  key_name   = "${var.name_prefix}-cluster-key"
  public_key = tls_private_key.cluster_key.public_key_openssh
}

# Resource 3: Store the generated private key content into a local file.
# This replaces the Secrets Manager integration.
resource "local_file" "private_key_file" {
  content         = tls_private_key.cluster_key.private_key_pem
  filename        = "cluster_key.pem"
  # Set permissions to read-only for the owner (REQUIRED by SSH clients)
  file_permission = "0400" 
}

/* # Resource 3: Store the generated private key in Secrets Manager
resource "aws_secretsmanager_secret" "private_key" {
  name        = "${var.name_prefix}-cluster-private-key"
  description = "Private SSH key for accessing EC2 Bastion host."
}

# Resource 4: Attach the private key content to the secret
resource "aws_secretsmanager_secret_version" "private_key_version" {
  secret_id     = aws_secretsmanager_secret.private_key.id
  secret_string = tls_private_key.cluster_key.private_key_pem
}
 */
 
# --- 2. MODULE CALLS ---

# Module 1: VPC Network Creation
module "k8s_vpc" {
  source = "./modules/vpc"

  name_prefix     = var.name_prefix
  environment     = var.environment
  vpc_cidr_block  = var.vpc_cidr_block
}

# Module 2: EC2 Compute Node Creation
# This module depends on the VPC outputs and the dynamically generated key.
module "cluster_nodes" {
  source = "./modules/compute"

  aws_region             = var.aws_region
  key_name               = aws_key_pair.cluster_key.key_name

  vpc_id                 = module.k8s_vpc.vpc_id
  public_subnet_id       = module.k8s_vpc.public_subnet_id
  private_subnet_ids     = module.k8s_vpc.private_subnet_ids
  vpc_cidr_block         = module.k8s_vpc.vpc_cidr_block_used
}

# --- 3. ANSIBLE INVENTORY ---

# Resource to generate the Ansible inventory file dynamically
resource "local_file" "inventory" {
  # The templatefile function reads the .tpl file and substitutes variables.
  content = templatefile("${path.module}/inventory.tpl", {
    # These values come from the 'cluster_nodes' module outputs:
    bastion_public_ip   = module.cluster_nodes.bastion_public_ip,
    master_private_ip   = module.cluster_nodes.master_private_ip,
    worker_private_ips  = module.cluster_nodes.worker_private_ips
  })
  
  # This is the name of the final, generated file that Ansible will use.
  filename = "${path.module}/inventory"
}