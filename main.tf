
provider "aws" {
  region = "us-east-2" # Change as needed
}

# Reference your existing VPC
data "aws_vpc" "target" {
  id = "vpc-04ab17a47803f2f91"
}

# Find an existing Internet Gateway or create one if needed
data "aws_internet_gateway" "existing" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.target.id]
  }
}

resource "aws_internet_gateway" "igw" {
  count  = length(data.aws_internet_gateway.existing.ids) == 0 ? 1 : 0
  vpc_id = data.aws_vpc.target.id
}

# Use existing IGW if present, else the new one
locals {
  igw_id = length(data.aws_internet_gateway.existing.ids) > 0 ? data.aws_internet_gateway.existing.id : aws_internet_gateway.igw[0].id
}

# Create a new public subnet (choose an available CIDR block in your VPC)
resource "aws_subnet" "public" {
  vpc_id                  = data.aws_vpc.target.id
  cidr_block              = "10.0.10.0/24" # Change if this overlaps with existing subnets
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"   # Change as needed

  tags = {
    Name = "public-subnet"
  }
}

# Create a route table for the public subnet
resource "aws_route_table" "public" {
  vpc_id = data.aws_vpc.target.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = local.igw_id
  }

  tags = {
    Name = "public-route-table"
  }
}

# Associate the route table with the public subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security group allowing SSH
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = data.aws_vpc.target.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # For production, restrict this!
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Find the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 instance in the public subnet
resource "aws_instance" "vault_linux" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  key_name               = "vault"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
  associate_public_ip_address = true

  tags = {
    Name = "vault-linux-instance"
  }
}

output "instance_public_ip" {
  value = aws_instance.vault_linux.public_ip
}
