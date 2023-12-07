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
  access_key = "AKIAZ5YM6QKGFKCPPEVI"
  secret_key = "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"
}

resource "aws_key_pair" "myawskey" {
  key_name   = "awskey"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCqE1hw4ThhehnvRjwRzSSeHxTlfkxI1VmqBoVMANkIhIYcb10bLqbkM/c4MbsiFdqajAmPNN4QmkoyBxhPgap0Qgn/ohVjsLQ+7zxi0BdnP7RC5KEpDFyN2gyBQ0q8jZk1nJgim061j5x262I3dg5YmPGaEf1ko77Nbx/yNci3mJkWC92vdZXUPG4mCiPP7fZgdhLcLXW8FJI1/9oK/V7Ja49nCO4SxGToJPQeKk6B4kU5nv37oQ5xJ+MkGLjblFebcCa07QabHuu5XQvKNi0C+Ru00dV0hj7+3Ku0KEjNescn3kpxZIDmV7gTGriVtQ9gzkYX41FqQpYIp4r80Xz/4BVN3oBLUJ5NQQNpEui1GCkAYtPLo88pfTaUdfYzrF25+F6n2V/I9ICKVW8qckIQsWcNM3RegeMJpaPYjr9akvH6m4n0HwJJFQcbSzgTn6DoJ8+nAqodsruOa6V8beIO4BgYn7hgb/0vWCzpcv0k9oVKacbvXjdKLErjgHzzp8khxTEWfwAaPmE2ahWv7ZcN8itH6L4RTG6eS7fvmcdWv6gcd5ueuk1hm61Fm8mEBuNCiJqGVVB5CwjEGxRUAtoSdK3Qp2aEEaz91SE+ZEtDMXa2NWpwfp/sqUxBBJImEFwU9VdzfCoe0BdLkBs0sr+p7n8582sv92dBaA68lziB/Q== sulaiman@master-node"
}

resource "aws_vpc" "sulaiman_vpc" {
  cidr_block = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "sulaiman_vpc"
  }
}

resource "aws_subnet" "selected_subnet" {
  vpc_id     = aws_vpc.sulaiman_vpc.id
  cidr_block = "10.0.1.0/24"
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

resource "aws_instance" "sulaiman_ec2" {
  ami             = "ami-0302f42a44bf53a45"
  instance_type   = "t2.micro"
  subnet_id       = resource.aws_subnet.selected_subnet.id
  security_groups = [aws_security_group.sulaiman_sg.id]
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
