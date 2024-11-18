terraform {
    required_providers {
      aws = {
        source = "hashicorp/aws"
        version = "3.38"
      }
    }
    required_version = "1.9.8"
}

provider "aws" {
    region = "us-east-2"
}

variable "nasty_port" {
  description = "web server port"
  default = 8080
  type = number
}

resource "aws_instance" "my_nasty_server" {
  ami = "ami-0ea3c35c5c3284d82"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.my_nasty_server_security_group.id]
  user_data = <<-EOF
    #!/bin/bash
    echo "Hello, World" > index.html
    nohup busybox httpd -f -p 8080 &
    EOF
  tags = {
    Name = "my-nasty-terraform-server"
  }
}

resource "aws_security_group" "my_nasty_server_security_group" {

  name = "nasty-security-group"

  ingress {
    from_port = var.nasty_port
    to_port = var.nasty_port
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
