terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.0, < 5.0"
    }
  }
}

provider "aws" {
  region     = "eu-west-3"
}

resource "tls_private_key" "mykey" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "aws_key_pair" "myawskey" {
    key_name = "macle"
    public_key = tls_private_key.mykey.public_key_openssh
}

resource "local_file" "mykeyfile" {
    content = tls_private_key.mykey.private_key_pem
    filename = "${path.module}/awsdevops.pem"
    file_permission = "0600"
}

resource "aws_vpc" "sulaiman_vpc" {
  cidr_block = "192.168.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "sulaiman_vpc"
  }
}

resource "aws_subnet" "sulaiman_subnet" {
  vpc_id     = aws_vpc.sulaiman_vpc.id
  cidr_block = "192.168.1.0/24"
}

resource "aws_security_group" "sulaiman_sg" {
  name        = "sulaiman_ssh"
  vpc_id      = resource.aws_vpc.sulaiman_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "allow SSH from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Setup Internet gateway
resource "aws_internet_gateway" "sulaiman_igw" {
  vpc_id = aws_vpc.sulaiman_vpc.id
}

# Setup Internet router
resource "aws_route_table" "sulaiman_route_table" {
  vpc_id = aws_vpc.sulaiman_vpc.id

  route {
    cidr_block = "192.168.1.0/24"
    gateway_id = aws_internet_gateway.sulaiman_igw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
  }

  tags = {
    Name = "sulaiman_route_table"
  }
}

resource "aws_route" "sulaiman_route" {
  route_table_id            = resource.aws_route_table.sulaiman_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.sulaiman_igw.id
}

resource "aws_instance" "sulaiman_ec2" {
  ami             = "ami-0302f42a44bf53a45"
  instance_type   = "t2.micro"
  subnet_id       = resource.aws_subnet.sulaiman_subnet.id
  security_groups = [aws_security_group.sulaiman_sg.id]
  associate_public_ip_address = true
  key_name        = aws_key_pair.myawskey.key_name

  count = 3

  tags = {
    Name = "sulaiman-ec2-node-${count.index + 1}"
  }
}


/* resource "aws_instance" "set_ansible" {
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y ansible",
      "ansible-playbook -i localhost, ../ansible/kubernetes_install.yml"
    ]
  }
} */
