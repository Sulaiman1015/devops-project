terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.0, < 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-3"
}

resource "tls_private_key" "mypem" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "myawskey" {
  key_name   = "myawskey"
  public_key = tls_private_key.mypem.public_key_openssh
}

resource "local_file" "pem_file" {
  filename             = pathexpand("~/.ssh/${local.ssh_key_name}.pem")
  file_permission      = "0600"
  directory_permission = "0700"
  content              = tls_private_key.mypem.private_key_pem
}

locals {
  ssh_key_name = "MyawsKey"
}

resource "aws_vpc" "sulaiman_vpc" {
  cidr_block       = "10.0.0.0/16"

  tags = {
    Name = "sulaiman_vpc"
  }
}

resource "aws_subnet" "sulaiman_public_subnet" {
  vpc_id      = aws_vpc.sulaiman_vpc.id
  cidr_block  = "10.0.1.0/24"
  availability_zone = "3a"

  tags = {
    Name = "sulaiman_pub_subnet"
  }
}

resource "aws_subnet" "sulaiman_private_subnet" {
  vpc_id      = aws_vpc.sulaiman_vpc.id
  cidr_block  = "10.0.2.0/24"
  availability_zone = "3a"

  tags = {
    Name = "sulaiman_private_subnet"
  }
}

resource "aws_security_group" "sulaiman_sg" {
  name        = "sulaiman_ssh_http"
  vpc_id      = aws_vpc.sulaiman_vpc.id
  description = "Allow SSH and HTTP access"

  # Rule allowing HTTP (port 80) access from anywhere for control node
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # You can restrict this to a specific IP range if needed
    description = "HTTP from any IP for control node"
  }

  # Rule allowing SSH (port 22) access from anywhere for all nodes
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # You can restrict this to a specific IP range if needed
    description = "SSH from any IP for all nodes"
  }

  # Rule allowing all outbound traffic from all nodes
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "sulaiman_sg"
  }
}




# Setup Internet gateway
resource "aws_internet_gateway" "sulaiman_igw" {
  vpc_id = aws_vpc.sulaiman_vpc.id

  tags = {
    Name = "sulaiman_igw"
  }
}

# Setup Internet router
resource "aws_route_table" "sulaiman_public_rt" {
  vpc_id = aws_vpc.sulaiman_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.sulaiman_igw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.sulaiman_igw.id
  }

  tags = {
    Name = "sulaiman_public_rt"
  }
}

resource "aws_route_table_association" "sulaiman_public_rta" {
  subnet_id      = aws_subnet.sulaiman_public_subnet
  route_table_id = aws_route_table.sulaiman_public_rt.id
}

resource "aws_instance" "control_node" {
  ami                             = "ami-0302f42a44bf53a45"
  instance_type                   = "t2.micro"
  key_name                        = aws_key_pair.myawskey.key_name

  subnet_id                       = aws_subnet.sulaiman_public_subnet.id
  vpc_security_group_ids          = [aws_security_group.sulaiman_web_sg.id]
  associate_public_ip_address     = true

  user_data = <<-EOF
  #!/bin/bash -ex

  amazon-linux-extras install nginx1 -y
  echo "<h1>The simplest thing is to learn. Congratulations, you succeeded!</h1>" >  /usr/share/nginx/html/index.html 
  systemctl enable nginx
  systemctl start nginx
  EOF
  
  tags = {
    Name = "sulaiman-control-node"
    Type = "control-node"
  }
}

resource "aws_instance" "managed_node" {
  ami                             = "ami-0302f42a44bf53a45"
  instance_type                   = "t2.micro"
  key_name                        = aws_key_pair.myawskey.key_name

  subnet_id                       = aws_subnet.sulaiman_private_subnet
  vpc_security_group_ids          = [aws_security_group.sulaiman_private_sg]
  associate_public_ip_address     = false
  count = 2

  tags = {
    Name = "sulaiman-managed-node-${count.index + 1}"
    Type = "managed-node"
  }
}