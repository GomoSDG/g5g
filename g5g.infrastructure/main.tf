# Specify the provider and access details

# We use vault to get credentials, but you can use variables to achieve the same thing

provider "aws" {
  region     = "${var.aws_region}"
}

### Network

# Fetch AZs in the current region
data "aws_availability_zones" "available" {}

resource "aws_vpc" "wishlist_vpc" {
  cidr_block = "10.1.0.0/20"
}

# Create var.az_count private subnets, each in a different AZ
resource "aws_subnet" "sb_wishlist_pv" {
  count             = "${var.az_count}"
  cidr_block        = "${cidrsubnet(aws_vpc.wishlist_vpc.cidr_block, 8, count.index)}"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  vpc_id            = "${aws_vpc.wishlist_vpc.id}"
}

# Create var.az_count public subnets, each in a different AZ
resource "aws_subnet" "sb_wishlist_pb" {
  count                   = "${var.az_count}"
  cidr_block              = "${cidrsubnet(aws_vpc.wishlist_vpc.cidr_block, 8, var.az_count + count.index)}"
  availability_zone       = "${data.aws_availability_zones.available.names[count.index]}"
  vpc_id                  = "${aws_vpc.wishlist_vpc.id}"
  map_public_ip_on_launch = true
}

# IGW for the public subnet
resource "aws_internet_gateway" "gw_wishlist" {
  vpc_id = "${aws_vpc.wishlist_vpc.id}"
}

# Route the public subnet traffic through the IGW
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.wishlist_vpc.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.gw_wishlist.id}"
}

# Create a NAT gateway with an EIP for each private subnet to get internet connectivity
#resource "aws_eip" "gw_wishlist" {
#  count      = "${var.az_count}"
#  vpc        = true
#  depends_on = ["aws_internet_gateway.gw_wishlist"]
#}

#resource "aws_nat_gateway" "gw" {
#  count         = "${var.az_count}"
#  subnet_id     = "${element(aws_subnet.sb_wishlist_pb.*.id, count.index)}"
#  allocation_id = "${element(aws_eip.gw_wishlist.*.id, count.index)}"
#}

# Create a new route table for the private subnets
# And make it route non-local traffic through the NAT gateway to the internet
#resource "aws_route_table" "private" {
#  count  = "${var.az_count}"
#  vpc_id = "${aws_vpc.wishlist_vpc.id}"

#  route {
#    cidr_block = "0.0.0.0/0"
#    nat_gateway_id = "${element(aws_nat_gateway.gw.*.id, count.index)}"
#  }
#}

# Explicitely associate the newly created route tables to the private subnets (so they don't default to the main route table)
#resource "aws_route_table_association" "private" {
#  count          = "${var.az_count}"
#  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
#  route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
#}

### Security

# ALB Security group
# This is the group you need to edit if you want to restrict access to your application
resource "aws_security_group" "lb" {
  name        = "tf-ecs-alb"
  description = "controls access to the ALB"
  vpc_id      = "${aws_vpc.wishlist_vpc.id}"

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol = "tcp"
    from_port = 443
    to_port = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Traffic to the ECS Cluster should only come from the ALB
resource "aws_security_group" "ecs_tasks" {
  name        = "tf-ecs-tasks"
  description = "allow inbound access from the ALB only"
  vpc_id      = "${aws_vpc.wishlist_vpc.id}"

  ingress {
    protocol        = "tcp"
    from_port       = 80
    to_port         = "${var.product-scraper_port}"
    security_groups = ["${aws_security_group.lb.id}"]
  }

  ingress {
    protocol        = "tcp"
    from_port       = 443
    to_port         = "${var.product-scraper_port}"
    security_groups = ["${aws_security_group.lb.id}"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

### ALB

resource "aws_lb" "main" {
  name            = "tf-ecs-chat"
  subnets         = "${aws_subnet.sb_wishlist_pb.*.id}"
  security_groups = ["${aws_security_group.lb.id}"]
}

resource "aws_alb_target_group" "product-scraper" {
  name        = "tf-ecs-chat"
  port        = 3003
  protocol    = "HTTP"
  vpc_id      = "${aws_vpc.wishlist_vpc.id}"
  target_type = "ip"
  health_check {
    path = "/"
    matcher = "200-299"
    port = 3003
  }
}

# Redirect all traffic from the ALB to the target group
resource "aws_alb_listener" "product-scraper" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.product-scraper.id}"
    type             = "forward"
  }
}

resource "aws_lb_listener" "product-scraper-secure" {
  load_balancer_arn = aws_lb.main.arn
  port = "443"
  protocol = "HTTPS"
  ssl_policy  = "ELBSecurityPolicy-2016-08"
  certificate_arn = "arn:aws:acm:af-south-1:139407860310:certificate/b01ad762-dae9-4193-8d29-c6cd29913aa8"

  default_action {
    target_group_arn = "${aws_alb_target_group.product-scraper.id}"
    type             = "forward"
  }
} 

### ECS

resource "aws_ecs_cluster" "wishlist" {
  name = "wishlist"
}

resource "aws_ecs_task_definition" "product-scraper" {
  family                   = "product-scraper"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "${var.fargate_cpu}"
  memory                   = "${var.fargate_memory}"
  execution_role_arn = "arn:aws:iam::139407860310:role/service"

  container_definitions = <<DEFINITION
[
  {
    "cpu": ${var.fargate_cpu},
    "image": "${var.product-scraper_image}",
    "memory": ${var.fargate_memory},
    "name": "product-scraper",
    "networkMode": "awsvpc",
    "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
           "awslogs-group": "product-scraper",
           "awslogs-region": "af-south-1",
           "awslogs-stream-prefix": "product-scraper"
        }
    },
    "portMappings": [
      {
        "containerPort": ${var.product-scraper_port},
        "hostPort": ${var.product-scraper_port}
      }
    ]
  }
]
DEFINITION
}

resource "aws_ecs_service" "wishlist" {
  name            = "wishlist"
  cluster         = "${aws_ecs_cluster.wishlist.id}"
  task_definition = "${aws_ecs_task_definition.product-scraper.arn}"
  desired_count   = "${var.product-scraper_count}"
  launch_type     = "FARGATE"

  network_configuration {
    security_groups = ["${aws_security_group.ecs_tasks.id}"]
    subnets         = "${aws_subnet.sb_wishlist_pb.*.id}"
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = "${aws_alb_target_group.product-scraper.id}"
    container_name   = "product-scraper"
    container_port   = "${var.product-scraper_port}"
  }

  depends_on = [
    "aws_alb_listener.product-scraper",
  ]
}
