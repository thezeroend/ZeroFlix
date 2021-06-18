variable "vpc_id" {}
variable "lambda_function_name" {
  type = string
}

data "aws_subnet_ids" "subnet" {
  vpc_id = var.vpc_id

  tags = {
    Tier = "Private"
  }

  filter {
    name = "cidr-block"
    value = ["172.31.0.0/20", "172.31.16.0/20"]
  }
}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_lambda_function" "selected" {
  function_name = var.lambda_function_name
}

resource "aws_lb_target_group" "tg-tokenexchange" {
  #health_check {
  #  interval = 10
  #  path = "/"
  #  protocol = "HTTP"
  #  timeout = 5
  #  healthy_threshold = 5
  #  unhealthy_threshold = 2
  #}

  name = "tg-tokenexchange"
  target_type = "lambda"
}

resource "aws_security_group" "allow_ports" {
  name = "alb"
  description = "Allow inbound traffic"
  vpc_id = "var.vpc_id"
  ingress {
    description = "http from VPC"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TLS from VPC"
    from_port = 443
    to_port = 443
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

resource "aws_lb" "alb-tokenexchange" {
  name = "alb-tokenexchange"
  internal = true
  security_groups = [
    "${aws_security_group.allow_ports.id}",
  ]

  subnets = data.aws_subnet_ids.subnet.ids

  tags = {
    Name = "alb-tokenexchange"
  }

  ip_address_type = "ipv4"
  load_balancer_type = "application"
}

resource "aws_lb_listener" "alb-tokenexchange-listener" {
  load_balancer_arn = aws_lb.alb-tokenexchange.arn
  port = 80
  protocol = "HTTP"
  default_action {
    target_group_arn = "${aws_lb_target_group.tg-tokenexchange.arn}"
    type = "forward"
  }
}

resource "aws_lambda_permission" "with_lb" {
  statement_id  = "AllowExecutionFromlb"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.selected.arn
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.tg-tokenexchange.arn
}

resource "aws_alb_target_group_attachment" "lambda_attach" {
  target_id = data.aws_lambda_function.selected.arn
  target_group_arn = aws_lb_target_group.tg-tokenexchange.arn
  depends_on = [aws_lambda_permission.with_lb]
}
