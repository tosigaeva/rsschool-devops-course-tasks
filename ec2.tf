resource "aws_instance" "bastion_host" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public_subnets[0].id
  vpc_security_group_ids = [
    aws_security_group.public.id,
    aws_security_group.private.id
  ]
  key_name = aws_key_pair.my_key.key_name
  tags = {
    Name = "Bastion Host"
  }
}

resource "aws_instance" "control_node" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public_subnets[0].id
  vpc_security_group_ids = [
    aws_security_group.public.id,
    aws_security_group.private.id,
    aws_security_group.k3s.id
  ]
  key_name = aws_key_pair.my_key.key_name
  tags = {
    Name = "K3S Control node"
  }
  user_data = <<-EOF
              #!/bin/bash
              sudo su
              apt update && curl -sfL https://get.k3s.io | sh -
              EOF
}

resource "aws_instance" "agent_node" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.private_subnets[0].id
  vpc_security_group_ids = [
    aws_security_group.public.id,
    aws_security_group.private.id,
    aws_security_group.k3s.id
  ]
  key_name = aws_key_pair.my_key.key_name
  tags = {
    Name = "K3S Agent node"
  }
  depends_on = [aws_instance.control_node]
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "tls_private_key" "my_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "my_key" {
  key_name   = "SSH Private Key to connect to EC2 instances"
  public_key = tls_private_key.my_key.public_key_openssh
}
