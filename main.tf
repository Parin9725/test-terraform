variable "project_name" {}
variable "environment" {}
variable "key_name" {}
variable "az_for_public_subnet_a" {}
variable "az_for_public_subnet_b" {}
variable "az_for_public_subnet_c" {}
variable "az_for_private_subnet_a" {}
variable "az_for_private_subnet_b" {}
variable "az_for_private_subnet_c" {}


provider "aws" {}

locals {
  app_name = "${var.project_name}-${var.environment}"
  dbname = "${var.project_name}${var.environment}"
}


resource "aws_vpc" "google" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = "true"

  tags = {
    Name = local.app_name
  }
}

resource "aws_internet_gateway" "google_igw" {
  vpc_id = "${aws_vpc.google.id}"

  tags = {
    Name = "${local.app_name}_igw"
  }
}

resource "aws_subnet" "google_public_a" {
  vpc_id     = "${aws_vpc.google.id}"
  cidr_block = "192.168.0.0/24"
  availability_zone = var.az_for_public_subnet_a
  map_public_ip_on_launch = "true"

  tags = {
    Name = "${local.app_name}_public_a"
  }
}

resource "aws_subnet" "google_public_b" {
  vpc_id     = "${aws_vpc.google.id}"
  cidr_block = "192.168.1.0/24"
  availability_zone = var.az_for_public_subnet_b
  map_public_ip_on_launch = "true"

  tags = {
    Name = "${local.app_name}_public_b"
  }
}

resource "aws_subnet" "google_public_c" {
  vpc_id     = "${aws_vpc.google.id}"
  cidr_block = "192.168.2.0/24"
  availability_zone = var.az_for_public_subnet_c
  map_public_ip_on_launch = "true"

  tags = {
    Name = "${local.app_name}_public_c"
  }
}

resource "aws_subnet" "google_private_a" {
  vpc_id     = "${aws_vpc.google.id}"
  cidr_block = "192.168.3.0/24"
  availability_zone = var.az_for_private_subnet_a
  map_public_ip_on_launch = "false"

  tags = {
    Name = "${local.app_name}_private_a"
  }
}

resource "aws_subnet" "google_private_b" {
  vpc_id     = "${aws_vpc.google.id}"
  cidr_block = "192.168.4.0/24"
  availability_zone = var.az_for_private_subnet_b
  map_public_ip_on_launch = "false"

  tags = {
    Name = "${local.app_name}_private_b"
  }
}

resource "aws_subnet" "google_private_c" {
  vpc_id     = "${aws_vpc.google.id}"
  cidr_block = "192.168.5.0/24"
  availability_zone = var.az_for_private_subnet_c
  map_public_ip_on_launch = "false"

  tags = {
    Name = "${local.app_name}_private_c"
  }
}

resource "aws_route_table" "google_public_route" {
  vpc_id = "${aws_vpc.google.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.google_igw.id}"
  }

  tags = {
    Name = "${local.app_name}_public_route"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.google_public_a.id
  route_table_id = aws_route_table.google_public_route.id
}
resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.google_public_b.id
  route_table_id = aws_route_table.google_public_route.id
}
resource "aws_route_table_association" "c" {
  subnet_id      = aws_subnet.google_public_c.id
  route_table_id = aws_route_table.google_public_route.id
}

resource "aws_security_group" "ecs_instance_sg" {
  name        = "ecs_instance_sg"
  description = "Allow TLS inbound traffic"
  vpc_id      = "${aws_vpc.google.id}"

  ingress {
    description = "TLS from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.app_name}_ecs_instance_sg"
  }
}

resource "aws_security_group" "google_alb__sg" {
  name        = "google_alb__sg"
  description = "Allow traffic from Internet"
  vpc_id      = "${aws_vpc.google.id}"

  ingress {
    description = "TLS from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.app_name}_alb__sg"
  }
}

resource "aws_lb" "google_alb" {
  name               = local.app_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.google_alb__sg.id}"]
  subnets            = ["${aws_subnet.google_public_a.id}", "${aws_subnet.google_public_b.id}", "${aws_subnet.google_public_c.id}"]
}

resource "aws_lb_target_group" "google_tg1"{
        name = "${local.app_name}-tg1"
        port = 80
        protocol = "HTTP"
        target_type = "instance"
        vpc_id = "${aws_vpc.google.id}"
}

resource "aws_lb_listener" "http" {
        load_balancer_arn = "${aws_lb.google_alb.arn}"
        port = "80"
        protocol = "HTTP"

        default_action {
                type = "forward"
                target_group_arn = "${aws_lb_target_group.google_tg1.arn}"
        }
}

resource "aws_ecs_cluster" "google" {
  name = local.app_name
}

resource "aws_ecr_repository" "google" {
  name                 = local.app_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }
}

resource "aws_launch_configuration" "google_launch_config" {
  name          = "${local.app_name}_launch_config"
  image_id    = "ami-0fca7970ac53c18de"
  instance_type = "t2.micro"
  security_groups = ["${aws_security_group.ecs_instance_sg.id}"]
  key_name = var.key_name
  user_data = <<-EOF
	      #!/bin/bash
	      echo ECS_CLUSTER=google >> /etc/ecs/ecs.config
	      EOF
  associate_public_ip_address = true
  iam_instance_profile = "ecsInstanceRole"
}

resource "aws_autoscaling_group" "google_ag" {
  name                      = "${local.app_name}_ag"
  max_size                  = 1
  min_size                  = 1
  health_check_grace_period = 300
  desired_capacity          = 1
  launch_configuration      = "${aws_launch_configuration.google_launch_config.name}"
  vpc_zone_identifier       = ["${aws_subnet.google_public_a.id}", "${aws_subnet.google_public_b.id}", "${aws_subnet.google_public_c.id}"]
  
  tag {
    key   = "Name"
    value = local.app_name
    propagate_at_launch = true
    }
}

resource "aws_rds_cluster" "google_serverless_db" {
  cluster_identifier      = "${local.app_name}-rds"
  engine                  = "aurora-postgresql"
  engine_mode             = "serverless"
  scaling_configuration {
    auto_pause               = true
    max_capacity             = 2
    min_capacity             = 2
    seconds_until_auto_pause = 900
    timeout_action           = "ForceApplyCapacityChange"
  }
  database_name           = local.dbname
  master_username         = "promactadmin"
  master_password         = "Promact2020!"
  backup_retention_period = 7
  preferred_backup_window = "07:00-09:00"
}

