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

resource "aws_instance" "my_nasty_server" {
  ami = "ami-013d21c7f48ae9ff1"
  instance_type = "t2.micro"
  tags = {
    Name = "my-nasty-terraform-server"
  }
}