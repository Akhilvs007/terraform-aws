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
    nohup busybox httpd -f -p ${var.nasty_port} &
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

output "public_ip" {
  value = aws_instance.my_nasty_server.public_ip
  description = "The public ip address of web server"
}

resource "aws_launch_configuration" "nasty_launch_config" {
  image_id = "ami-0ea3c35c5c3284d82"
  instance_type = "t2.micro"
  security_groups = [aws_security_group.my_nasty_server_security_group.id]
  user_data = <<-EOF
    #!/bin/bash
    echo "Hello, World" > index.html
    nohup busybox httpd -f -p ${var.nasty_port} &
    EOF

  lifecycle {
    create_before_destroy = true
  }
}
#get the details of VPC
data "aws_vpc" "default" {
  default = true
}

#Use the default VPC id and get the default subnet id's
data "aws_subnet_ids" "default_subnet_ids" {
  vpc_id = data.aws_vpc_default.default.id
}

resource "aws_autoscaling_group" "nastry_scale_group" {
  launch_configuration = aws_launch_configuration.nasty_launch_config.name
  #Use the default subnet id's
  vpc_zone_identifier = data.aws_subnet_ids.default_subnet_ids.ids
  min_size = 2
  max_size = 10

  tag {
    key     = "Name"
    value   = "terraform-asg-example"
    propagate_at_launch = true
  }
}

resource "aws_lb" "my_nasty_lb" {
  name = "terraform-asg-example"
  load_balancer_type = "application"
  subnets = data.aws_subnet_ids.default_subnet_ids.ids
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.my_nasty_lb.arn
  port = 80
  protocol = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code = 404
    }
  }
}