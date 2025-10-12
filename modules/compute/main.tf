# Data source to fetch the latest Ubuntu 22.04 LTS AMI in the current region
data "aws_ami" "ubuntu_ami" {
  most_recent = true
  filter {
    # Searches for the latest Ubuntu 22.04 LTS (Jammy) server image
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  # Canonical's official AWS Account ID (099720109477)
  owners = ["099720109477"] 
}

# ----------------------------------------------------------------------------
# 1. CLUSTER COMPUTE SECURITY GROUP (SG) - Master and Workers
# ----------------------------------------------------------------------------

resource "aws_security_group" "compute_sg" {
  name_prefix = "cluster-nodes-sg-"
  description = "Security group for Master and Worker nodes (internal traffic and SSH via Bastion)"
  vpc_id      = var.vpc_id

  # RULE 1: Allow all internal traffic for cluster communication (from anywhere in the VPC)
  ingress {
    description = "Allow all VPC internal traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr_block]
  }

  # RULE 2: Allow SSH ONLY from the Bastion Host's Security Group ID
  # Terraform automatically infers the dependency on aws_security_group.bastion_sg
  ingress {
    description     = "SSH access via Bastion Host only"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cluster-nodes-sg"
  }
}
# ----------------------------------------------------------------------------
# 2. MASTER NODE (1 instance, t3.medium)
# ----------------------------------------------------------------------------

resource "aws_instance" "master" {
  ami           = data.aws_ami.ubuntu_ami.id
  instance_type = "t3.medium"
  key_name      = var.key_name
  
  # Place the master in the first private subnet
  subnet_id = var.private_subnet_ids[0]

  vpc_security_group_ids = [aws_security_group.compute_sg.id]

  tags = {
    Name    = "k8s-master-node-0"
    Role    = "master"
    Region  = var.aws_region
  }
}

# ----------------------------------------------------------------------------
# 3. WORKER NODES (2 instances, t3.small)
# ----------------------------------------------------------------------------

# Use a map to define worker nodes and loop over them
locals {
  worker_nodes = {
    "worker-1" = { subnet_index = 1 }, # Subnet 1 (second private subnet)
    "worker-2" = { subnet_index = 2 }, # Subnet 2 (third private subnet)
  }
}

resource "aws_instance" "workers" {
  for_each      = local.worker_nodes
  ami           = data.aws_ami.ubuntu_ami.id
  instance_type = "t3.small"
  key_name      = var.key_name
  
  # Assign each worker to a different private subnet
  subnet_id = var.private_subnet_ids[each.value.subnet_index]

  vpc_security_group_ids = [aws_security_group.compute_sg.id]

  tags = {
    Name    = "k8s-worker-${each.key}"
    Role    = "worker"
    Region  = var.aws_region
  }
}

# ----------------------------------------------------------------------------
# 4. BASTION HOST (1 instance, t2.micro)
# ----------------------------------------------------------------------------

resource "aws_security_group" "bastion_sg" {
  name_prefix = "bastion-sg-"
  description = "Security group for Bastion host (SSH access from outside)"
  vpc_id      = var.vpc_id

  # Allow SSH (Port 22) access from your home IP or a specific range (CRITICAL for security)
  # NOTE: Replace "0.0.0.0/0" with your actual IP address/CIDR block for security!
  ingress {
    description = "SSH access from Internet"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # TODO: Restrict this to your specific IP
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bastion-sg"
  }
}

resource "aws_instance" "bastion" {
  ami           = data.aws_ami.ubuntu_ami.id
  instance_type = "t2.micro"
  key_name      = var.key_name
  
  # Place the bastion in the single public subnet
  subnet_id = var.public_subnet_id

  # Bastion needs a public IP to be accessed
  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.bastion_sg.id]

  tags = {
    Name    = "bastion-host"
    Role    = "bastion"
    Region  = var.aws_region
  }
}
