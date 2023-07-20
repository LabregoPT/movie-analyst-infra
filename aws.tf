# -------------------------------------------------------------------------
# Main AWS Infra configuration
# -------------------------------------------------------------------------

## Main AWS Cloud network
resource "aws_vpc" "aws-cloud" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "Main VPC"
  }
}

## VPC Subnets
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.aws-cloud.id
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-west-2a"
  tags = {
    Name = "Public Subnet 1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.aws-cloud.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-west-2b"
  tags = {
    Name = "Public Subnet 2"
  }
}

## Internet Gateway
resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.aws-cloud.id
  tags = {
    Name = "Main Gateway"
  }
}

##Application Load Balancer
resource "aws_lb" "load_balancer" {
  tags = {
    name = "Application Load Balancer"
  }
  name = "Load-Balancer"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.alb_security_group.id]
  subnets         = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
}

##ALB Listener
resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = aws_lb.load_balancer.arn
  port = "3000"
  protocol = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.front_target_group.arn
  }
  
}

##ALB Target Group
resource "aws_lb_target_group" "front_target_group" {
  name        = "front-facing-target-group"
  target_type = "instance"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.aws-cloud.id
  tags = {
    name = "Front Facing Target Group"
  }
}

##ALB Security Group
resource "aws_security_group" "alb_security_group" {
  vpc_id = aws_vpc.aws-cloud.id
  name   = "HTTP from Internet"
  ingress {
    from_port        = 3000
    to_port          = 3000
    protocol         = "TCP"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    from_port        = 3001
    to_port          = 3001
    protocol         = "TCP"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    from_port        = 3000
    to_port          = 3000
    protocol         = "TCP"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    from_port        = 3001
    to_port          = 3001
    protocol         = "TCP"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

##EC2 Instances to run server
resource "aws_instance" "server_1" {
  ami             = "ami-0c65adc9a5c1b5d7c"
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.public_subnet_1.id
  security_groups = [aws_security_group.private_ssh.id, aws_security_group.alb_security_group.id]
  key_name        = aws_key_pair.bastion_key.key_name
  #Initialization Script
  user_data = file("./front-init-script.sh")
  tags = {
    Name = "Frontend Server #1"
  }
}
resource "aws_instance" "server_2" {
  ami             = "ami-0c65adc9a5c1b5d7c"
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.public_subnet_2.id
  security_groups = [aws_security_group.private_ssh.id, aws_security_group.alb_security_group.id]
  key_name        = aws_key_pair.bastion_key.key_name
  #Initialization Script
  user_data = file("./front-init-script.sh")
  tags = {
    Name = "Frontend Server #2"
  }
}

##Attach Instances to ALBTG
resource "aws_lb_target_group_attachment" "albtg_attachment_1" {
  target_group_arn = aws_lb_target_group.front_target_group.arn
  target_id        = aws_instance.server_1.id
}
resource "aws_lb_target_group_attachment" "albtg_attachment_2" {
  target_group_arn = aws_lb_target_group.front_target_group.arn
  target_id        = aws_instance.server_2.id
}