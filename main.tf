terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  profile = "default"
  region  = "us-west-2"
}

resource "aws_vpc" "CoalFire_vpc" {
  cidr_block = var.vpc_cidr
}

resource "aws_subnet" "Sub1" {
  vpc_id                  = aws_vpc.CoalFire_vpc.id
  cidr_block              = var.vpc_public_subnets[0]
  availability_zone       = var.vpc_azs[0]
  map_public_ip_on_launch = true
  tags = {
    Name = "Sub1"
  }
}

resource "aws_subnet" "Sub2" {
  vpc_id                  = aws_vpc.CoalFire_vpc.id
  cidr_block              = var.vpc_public_subnets[1]
  availability_zone       = var.vpc_azs[1]
  map_public_ip_on_launch = true
  tags = {
    Name = "Sub2"
  }
}

resource "aws_subnet" "Sub3" {
  vpc_id            = aws_vpc.CoalFire_vpc.id
  cidr_block        = var.vpc_private_subnets[0]
  availability_zone = var.vpc_azs[0]
  tags = {
    Name = "Sub3"
  }
}

resource "aws_subnet" "Sub4" {
  vpc_id            = aws_vpc.CoalFire_vpc.id
  cidr_block        = var.vpc_private_subnets[1]
  availability_zone = var.vpc_azs[1]
  tags = {
    Name = "Sub4"
  }
}

resource "aws_internet_gateway" "CoalFire_internet_gateway" {
  vpc_id = aws_vpc.CoalFire_vpc.id
}

resource "aws_nat_gateway" "CoalFire_nat_gateway" {
  allocation_id = aws_eip.CoalFire_eip.id
  subnet_id     = aws_subnet.Sub1.id
}

resource "aws_route_table" "CoalFire_public_route_table" {
  vpc_id = aws_vpc.CoalFire_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.CoalFire_internet_gateway.id
  }
}

resource "aws_route_table" "CoalFire_private_route_table" {
  vpc_id = aws_vpc.CoalFire_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.CoalFire_nat_gateway.id
  }
}

resource "aws_route_table_association" "Sub1_route_table_association" {
  subnet_id      = aws_subnet.Sub1.id
  route_table_id = aws_route_table.CoalFire_public_route_table.id
}

resource "aws_route_table_association" "Sub2_route_table_association" {
  subnet_id      = aws_subnet.Sub2.id
  route_table_id = aws_route_table.CoalFire_public_route_table.id
}

resource "aws_route_table_association" "Sub3_route_table_association" {
  subnet_id      = aws_subnet.Sub3.id
  route_table_id = aws_route_table.CoalFire_private_route_table.id
}

resource "aws_route_table_association" "Sub4_route_table_association" {
  subnet_id      = aws_subnet.Sub4.id
  route_table_id = aws_route_table.CoalFire_private_route_table.id
}

resource "aws_eip" "CoalFire_eip" {
  vpc = true
}

module "ec2_instances" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  version                = "4.1.4"
  name                   = var.ec2_name
  ami                    = var.ec2_ami
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.CoalFire_ec2_sg.id]
  subnet_id              = aws_subnet.Sub2.id
  root_block_device = [{
    volume_type = "gp2"
    volume_size = 20
  }]
}

resource "aws_launch_configuration" "CoalFire_launch_config" {
  name             = "CoalFire_launch_config"
  image_id         = var.ec2_ami
  instance_type    = "t2.micro"
  security_groups  = [aws_security_group.CoalFire_ec2_sg.id]
  user_data_base64 = base64encode(local.instance_userdata)
}

resource "aws_autoscaling_group" "CoalFire_asg" {
  name                 = "CoalFire_asg"
  min_size             = 2
  max_size             = 6
  health_check_type    = "EC2"
  vpc_zone_identifier  = [aws_subnet.Sub3.id, aws_subnet.Sub4.id]
  launch_configuration = aws_launch_configuration.CoalFire_launch_config.name
  force_delete         = true
  target_group_arns    = [aws_lb_target_group.CoalFire-lb-target-group.arn]
  tag {
    key                 = "asg_ec2_coalfire"
    value               = "created_ec2"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "CoalFire_asg_policy" {
  name                   = "CoalFire_asg_policy"
  autoscaling_group_name = aws_autoscaling_group.CoalFire_asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  policy_type            = "SimpleScaling"
}

resource "aws_cloudwatch_metric_alarm" "CoalFire_asg_alarm" {
  alarm_name          = "CoalFire_asg_alarm"
  alarm_description   = "alarm to trigger autoscaling for ec2 instance"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  period              = "120"
  statistic           = "Average"
  threshold           = "65"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  dimensions = {
    "AutoScalingGroupName" : aws_autoscaling_group.CoalFire_asg.name
  }
  actions_enabled = true
  alarm_actions   = [aws_autoscaling_policy.CoalFire_asg_policy.arn]
}

resource "aws_autoscaling_policy" "CoalFire_descale_policy" {
  name                   = "CoalFire_descale_policy"
  autoscaling_group_name = aws_autoscaling_group.CoalFire_asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  policy_type            = "SimpleScaling"
}

resource "aws_cloudwatch_metric_alarm" "CoalFire_descale_alarm" {
  alarm_name          = "CoalFire_descale_alarm"
  alarm_description   = "alarm to trigger descaling for ec2 instance"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  period              = "120"
  statistic           = "Average"
  threshold           = "10"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  dimensions = {
    "AutoScalingGroupName" : aws_autoscaling_group.CoalFire_asg.name
  }
  actions_enabled = true
  alarm_actions   = [aws_autoscaling_policy.CoalFire_descale_policy.arn]
}

resource "aws_lb" "CoalFire-lb" {
  name               = "CoalFire-lb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.CoalFire_elb_sg.id]
  subnets            = [aws_subnet.Sub1.id, aws_subnet.Sub2.id]
}

resource "aws_lb_target_group" "CoalFire-lb-target-group" {
  name     = "CoalFire-lb-target-group"
  port     = "80"
  protocol = "HTTP"
  vpc_id   = aws_vpc.CoalFire_vpc.id
  health_check {
    matcher = "200-499"
  }
}

resource "aws_lb_listener" "CoalFire-lb-listener" {
  load_balancer_arn = aws_lb.CoalFire-lb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.CoalFire-lb-target-group.arn
  }
}

resource "aws_security_group" "CoalFire_elb_sg" {
  name   = "CoalFire_elb_sg"
  vpc_id = aws_vpc.CoalFire_vpc.id
  ingress {
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
}

resource "aws_security_group" "CoalFire_ec2_sg" {
  name   = "CoalFire_ec2_sg"
  vpc_id = aws_vpc.CoalFire_vpc.id
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.CoalFire_elb_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_s3_bucket" "coalfire-s3-bucket" {
  bucket = "coalfire-s3-bucket"
  lifecycle_rule {
    prefix  = "images/"
    enabled = true
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
  }
  lifecycle_rule {
    prefix  = "logs/"
    enabled = true
    expiration {
      days = 90
    }
  }
}

resource "aws_s3_object" "s3_images" {
  bucket = aws_s3_bucket.coalfire-s3-bucket.id
  key    = "images"
}

resource "aws_s3_object" "s3_Logs" {
  bucket = aws_s3_bucket.coalfire-s3-bucket.id
  key    = "logs"
}