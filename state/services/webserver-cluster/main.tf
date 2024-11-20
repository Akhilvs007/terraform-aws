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

terraform {
  backend "s3" {
    bucket = "my-nasty-s3-bucket"
    key = "stage/services/webserver-cluster/terraform.tfstate"
    region = "us-east-2"
    dynamodb_table = "my-nasty-aws-dynamodb-table"
    encrypt = true
  }
}
variable "nasty_port" {
  description = "web server port"
  default = 8080
  type = number
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
  vpc_id = data.aws_vpc.default.id
}

resource "aws_autoscaling_group" "nastry_scale_group" {
  launch_configuration = aws_launch_configuration.nasty_launch_config.name
  #Use the default subnet id's
  vpc_zone_identifier = data.aws_subnet_ids.default_subnet_ids.ids
  target_group_arns = [aws_lb_target_group.nasty_asg_target_group.arn]
  health_check_type = "ELB"
  min_size = 2
  max_size = 10

  tag {
    key     = "Name"
    value   = "terraform-asg-example"
    propagate_at_launch = true
  }
}

resource "aws_security_group" "nasty_alb_security_group" {
  name = "terraform-example-alb"

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "my_nasty_lb" {
  name = "terraform-asg-example"
  load_balancer_type = "application"
  subnets = data.aws_subnet_ids.default_subnet_ids.ids
  security_groups = [aws_security_group.my_nasty_server_security_group.id]
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

resource "aws_lb_target_group" "nasty_asg_target_group" {
  name = "terraform-example-target-group"
  port = var.nasty_port
  protocol = "HTTP"
  vpc_id = data.aws_vpc.default.id
  
  health_check {
    path = "/"
    protocol = "HTTP"
    matcher = "200"
    interval = 15
    timeout = 3
    healthy_threshold = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority = 1
  condition {
    path_pattern {
      values = ["*"]
    }
  }
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.nasty_asg_target_group.arn
  }
}

output "alb_dns_name" {
  value = aws_lb.my_nasty_lb.dns_name
  description = "The domain name of load balancer"
}
