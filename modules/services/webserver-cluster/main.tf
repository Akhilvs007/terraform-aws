locals {
  http_port    = 80
  any_port     = 0
  any_protocol = "-1"
  tcp_protocol = "tcp"
  all_ips      = ["0.0.0.0/0"]
}

variable "nasty_port" {
  description = "web server port"
  default = 8080
  type = number
}

resource "aws_security_group" "my_nasty_server_security_group" {

  name = "${var.cluster_name}-instance"

  ingress {
    from_port = var.nasty_port
    to_port = var.nasty_port
    protocol = local.tcp_protocol
    cidr_blocks = local.all_ips
  }
}


# resource "aws_launch_configuration" "nasty_launch_config" {
#   image_id = "ami-0ea3c35c5c3284d82"
#   instance_type = var.instance_type
#   security_groups = [aws_security_group.my_nasty_server_security_group.id]
#   user_data = <<-EOF
#     #!/bin/bash
#     echo "Hello, World" > index.html
#     nohup busybox httpd -f -p ${var.nasty_port} &
#     EOF

#   lifecycle {
#     create_before_destroy = true
#   }
# }

resource "aws_launch_template" "nasty_launch_config" {
  name = "nasty-launch-template"
  image_id = "ami-0942ecd5d85baa812"
  instance_type = var.instance_type
  security_group_names = [aws_security_group.my_nasty_server_security_group.name]
  block_device_mappings {
    device_name = "/dev/sdf"
    ebs {
      volume_size = 10
      delete_on_termination = true 
      volume_type = "gp2"
    }
  }
  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo "Hello, World" > index.html
    nohup busybox httpd -f -p ${var.nasty_port} &
    EOF
  )
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

resource "aws_autoscaling_group" "nasty_scale_group" {
  #launch_configuration = aws_launch_configuration.nasty_launch_config.name
  launch_template {
    id = aws_launch_template.nasty_launch_config.id
  }
  #Use the default subnet id's
  vpc_zone_identifier = data.aws_subnet_ids.default_subnet_ids.ids
  target_group_arns = [aws_lb_target_group.nasty_asg_target_group.arn]
  health_check_type = "ELB"
  min_size = var.min_size
  max_size = var.max_size

  tag {
    key     = "Name"
    value   = "${var.cluster_name}-asg"
    propagate_at_launch = true
  }
}

resource "aws_security_group" "nasty_alb_security_group" {
  name = "${var.cluster_name}-alb"

  ingress {
    from_port = local.http_port
    to_port = local.http_port
    protocol = local.tcp_protocol
    cidr_blocks = local.all_ips
  }

  egress {
    from_port = local.any_port
    to_port = local.any_port
    protocol = local.any_protocol
    cidr_blocks = local.all_ips
  }
}

resource "aws_lb" "my_nasty_lb" {
  name = "${var.cluster_name}-alb"
  load_balancer_type = "application"
  subnets = data.aws_subnet_ids.default_subnet_ids.ids
  security_groups = [aws_security_group.my_nasty_server_security_group.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.my_nasty_lb.arn
  port = local.http_port
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
  name = "${var.cluster_name}-target-group"
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