# modules/vpc/main.tf (Module)

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

# Get the available Availability Zones (AZs) in the current AWS region.
data "aws_availability_zones" "available" {
  state = "available"
}

# -----------------------------------------------------------------------------
# VPC and Gateway Resources
# -----------------------------------------------------------------------------

# Resource: AWS VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.name_prefix}-${var.environment}-vpc"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Resource: Internet Gateway (IGW) for public access
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-${var.environment}-igw"
  }
}

# Resource: Elastic IP (EIP) for the NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
  # This tag is necessary for monitoring and cost allocation
  tags = {
    Name = "${var.name_prefix}-${var.environment}-nat-eip"
  }
}

# -----------------------------------------------------------------------------
# Subnets (Public for Bastion/NAT and Private for Application)
# -----------------------------------------------------------------------------

# 1. Public Subnet (located in the first AZ)
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  # Uses 10.0.0.0/24 (Subnet index 0)
  cidr_block              = cidrsubnet(var.vpc_cidr_block, 8, 0)
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.name_prefix}-${var.environment}-public-subnet-az1"
    Environment = var.environment
    Tier        = "Public"
  }
}

# 2. Private Subnets (3 subnets, one in each of the first three AZs)
# We use 'for_each' to create multiple subnets and ensure they are spread across AZs.
resource "aws_subnet" "private" {
  # Limit to the first 3 available AZs
  for_each = toset(slice(data.aws_availability_zones.available.names, 0, 3))

  vpc_id            = aws_vpc.main.id
  # Subnet indices 1, 2, 3 (e.g., 10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24)
  cidr_block        = cidrsubnet(var.vpc_cidr_block, 8, index(data.aws_availability_zones.available.names, each.value) + 1)
  availability_zone = each.value

  tags = {
    Name        = "${var.name_prefix}-${var.environment}-private-subnet-${index(data.aws_availability_zones.available.names, each.value) + 1}"
    Environment = var.environment
    Tier        = "Private"
  }
}

# -----------------------------------------------------------------------------
# NAT Gateway
# -----------------------------------------------------------------------------

# Resource: NAT Gateway (must be placed in the Public Subnet)
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  depends_on    = [aws_internet_gateway.main]

  tags = {
    Name = "${var.name_prefix}-${var.environment}-nat-gw"
  }
}

# -----------------------------------------------------------------------------
# Route Tables and Associations
# -----------------------------------------------------------------------------

# 1. Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    # Route all external traffic (0.0.0.0/0) to the Internet Gateway (IGW)
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.name_prefix}-${var.environment}-public-rt"
  }
}

# Association: Public Subnet -> Public Route Table
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# 2. Private Route Table
# Create one private route table (which will be shared by all 3 private subnets)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    # Route all external traffic (0.0.0.0/0) to the NAT Gateway
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.name_prefix}-${var.environment}-private-rt"
  }
}

# Association: Private Subnets -> Private Route Table
# Loop through all created private subnets and associate them with the private RT
resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}