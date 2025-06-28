resource "aws_vpc" "root" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "RS VPC"
  }
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.root.id

  tags = {
    Name = "Gateway"
  }
}
