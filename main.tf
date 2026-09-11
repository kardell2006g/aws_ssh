provider "aws" {
  region = "us-east-2"
}

data "aws_vpc" "target" {
  id = "vpc-04ab17a47803f2f91"
}

data "aws_internet_gateway" "existing" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.target.id]
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = data.aws_vpc.target.id
  cidr_block              = "10.64.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-2a"
  tags = {
    Name = "public-subnet"
  }
}

resource "aws_route_table" "public" {
  vpc_id = data.aws_vpc.target.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_internet_gateway.existing.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
