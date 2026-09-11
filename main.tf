provider "aws" {
  region = "us-east-2"
}

data "aws_vpc" "target" {
  id = "vpc-04ab17a47803f2f91"
}

data "aws_internet_gateways" "existing" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.target.id]
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = data.aws_vpc.target.id
}

locals {
  igw_id = length(data.aws_internet_gateways.existing.ids) > 0 ? data.aws_internet_gateways.existing.ids[0] : aws_internet_gateway.igw[0].id
}
