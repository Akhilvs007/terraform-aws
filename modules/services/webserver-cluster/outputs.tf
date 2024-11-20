output "alb_dns_name" {
  value = aws_lb.my_nasty_lb.dns_name
  description = "The domain name of load balancer"
}
