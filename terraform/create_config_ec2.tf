

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
  ssh_key_name = "myawsKey"
}

resource "aws_default_vpc" "default" {
    tags = {
        Name = "default"
    }
}


resource "aws_security_group" "devops_sg" {
  name        = "devops_ssh_http"
  vpc_id      = aws_default_vpc.default.id
  description = "Allow SSH access"

  /* ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  } */

  ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = [ "0.0.0.0/0" ]
        description = "SSH from any ip"
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = [ "0.0.0.0/0" ]
    }


  tags = {
    Name = "devops_sg"
  }
}

resource "aws_instance" "managed_nodes" {
  ami                             = "ami-04b7bf9494d21c5bb"
  instance_type                   = "t2.micro"
  key_name                        = aws_key_pair.myawskey.key_name

  vpc_security_group_ids          = [aws_security_group.devops_sg.id]
  associate_public_ip_address     = true

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir /opt/app",
    ]
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = tls_private_key.mypem.private_key_pem
    host        = self.public_ip
  }

  count                           = 2
  tags = {
    Name = "devops-managed-node-${count.index + 1}"
    Type = "managed-nodes"
  }

}

resource "aws_instance" "control_node" {
  ami                             = "ami-0302f42a44bf53a45"
  instance_type                   = "t2.micro"
  key_name                        = aws_key_pair.myawskey.key_name

  vpc_security_group_ids          = [aws_security_group.devops_sg.id]
  associate_public_ip_address     = true
  
  tags = {
    Name = "devops-control-node"
    Type = "control-node"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo amazon-linux-extras install -y epel",
      "sudo useradd devops",
      "echo -e 'devops\ndevops' | sudo passwd devops",
      "echo 'devops ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/devops",
      "sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config",
      "sudo systemctl restart sshd.service",
      "sudo yum update -y",
      "sudo yum install -y ansible",
      "sudo mkdir /etc/ansible",
      "sudo touch /etc/ansible/ansible.cfg",
      "sudo echo '[defaults]\ninventory = /etc/ansible/host\nhost_key_checking = False\nremote_user = devops' > /etc/ansible/ansible.cfg",
      "sudo ansible-config init --disabled > ansible.cfg",
      "sudo touch /etc/ansible/hosts",
      "sudo echo '[control-node]\ndevops-control-node ansible_host=10.0.1.149 ansible_user=ec2_user\n[managed-nodes]\ndevops-managed-node-1 ansible_host=10.0.2.186 ansible_user=ec2_user\ndevops-managed-node-2 ansible_host=10.0.1.24 ansible_user=ec2_user' > /etc/ansible/hosts"
    ]
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = tls_private_key.mypem.private_key_pem
    host        = self.public_ip
  } 
}