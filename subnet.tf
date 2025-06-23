resource "aws_subnet" "public_subnets" {
  count             = length(var.public_subnets)
  vpc_id            = aws_vpc.root.id
  cidr_block        = element(var.public_subnets, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = "Public Subnet: ${count.index + 1}"
  }
}

resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.root.id
  cidr_block        = element(var.private_subnets, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = "Private Subnet: ${count.index + 1}"
  }
}
