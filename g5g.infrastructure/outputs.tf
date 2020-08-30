output "alb_hostname" {
  value = "${aws_lb.main.dns_name}"
}
