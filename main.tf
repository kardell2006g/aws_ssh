provider "aws" {
  region = "us-east-1" # Change as needed
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

# Reference your existing VPC
data "aws_vpc" "target" {
  id = "vpc-04ab17a47803f2f91"
}

# Find all subnets in the VPC (use the first one)
data "aws_subnets" "target" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.target.id]
  }
}

data "aws_subnet" "target" {
  id = data.aws_subnets.target.ids[0]
}

# Security group in the specified VPC
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

# EC2 instance in the specified subnet
resource "aws_instance" "vault_linux" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  key_name               = "vault"
  subnet_id              = data.aws_subnet.target.id
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]

  tags = {
    Name = "vault-linux-instance"
  }
}

output "instance_public_ip" {
  value = aws_instance.vault_linux.public_ip
}
