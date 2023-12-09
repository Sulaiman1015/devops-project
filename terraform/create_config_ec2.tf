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
  key_name   = "awskey"
  public_key = tls_private_key.mypem.public_key_openssh
}

resource "local_file" "mykeyfile" {
  content          = tls_private_key.mypem.private_key_pem
  filename         = "${path.module}/awskey.pem"
  file_permission  = "0600"
}

resource "aws_vpc" "sulaiman_vpc" {
  cidr_block        = "192.168.0.0/16"
  instance_tenancy  = "default"

  tags = {
    Name = "sulaiman_vpc"
  }
}

resource "aws_subnet" "sulaiman_subnet" {
  vpc_id      = aws_vpc.sulaiman_vpc.id
  cidr_block  = "192.168.1.0/24"
  map_public_ip_on_launch = true
}

resource "aws_security_group" "sulaiman_sg" {
  name        = "sulaiman_ssh"
  vpc_id      = aws_vpc.sulaiman_vpc.id
  description = "Allow SSH access"

  ingress = [{
    description      = "ingress port 22 allow"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0",] # Your current ip, or change to 0.0.0.0/0 to allow all
    self             = true
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    security_groups  = []
  }]

  egress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    description      = "egress allow all"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    self             = false
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    security_groups  = []
  }]


  tags = {
    Name = "sulaiman_ssh_security_group"
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
resource "aws_route_table" "sulaiman_route_table" {
  vpc_id = aws_vpc.sulaiman_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.sulaiman_igw.id
  }

  tags = {
    Name = "sulaiman_route_table"
  }
}

resource "aws_route" "sulaiman_route" {
  route_table_id            = aws_route_table.sulaiman_route_table.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id                = aws_internet_gateway.sulaiman_igw.id
}

resource "aws_instance" "control_node" {
  ami                             = "ami-0302f42a44bf53a45"
  instance_type                   = "t2.micro"
  subnet_id                       = aws_subnet.sulaiman_subnet.id
  security_groups                 = [aws_security_group.sulaiman_sg.id]
  associate_public_ip_address     = true
  key_name                        = aws_key_pair.myawskey.key_name

  tags = {
    Name = "sulaiman-control-node"
    Type = "control-node"
  }
}

resource "aws_instance" "managed_node" {
  ami                             = "ami-0302f42a44bf53a45"
  instance_type                   = "t2.micro"
  subnet_id                       = aws_subnet.sulaiman_subnet.id
  security_groups                 = [aws_security_group.sulaiman_sg.id]
  associate_public_ip_address     = true
  key_name                        = aws_key_pair.myawskey.key_name

  count = 2

  tags = {
    Name = "sulaiman-managed-node-${count.index + 1}"
    Type = "managed-node"
  }
}