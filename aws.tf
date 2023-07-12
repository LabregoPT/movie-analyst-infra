resource "aws_vpc" "aws-cloud" {
  #Main AWS Cloud network
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "gateway" {
  #Required to allow access from outside the VPC

  vpc_id = aws_vpc.aws-cloud.id

  tags = {
    Name = "main"
  }
}

##VPC Subnets
resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.aws-cloud.id
  availability_zone = "us-west-2a"
  cidr_block = "10.0.10.0/24"
  map_public_ip_on_launch = true
  tags = {
    name = "public subnet"
  }
}

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.aws-cloud.id
  availability_zone = "us-west-2a"
  cidr_block = "10.0.20.0/24"
  map_public_ip_on_launch = false
  tags = {
    name = "private subnet"
  }
}

# route tables
resource "aws_route_table" "main-public" {
  vpc_id = aws_vpc.aws-cloud.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway.id
  }
  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.gateway.id
  }
  tags = {
    Name = "main-public"
  }
}

resource "aws_route_table_association" "main-public-1-a" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.main-public.id
}

#-------------------------
# Bastion Host Configuration
#-------------------------



##Security Group
resource "aws_security_group" "ssh_from_internet" {
  vpc_id = aws_vpc.aws-cloud.id
  name = "ssh_from_internet"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    name = "public-ssh"
  }
}

resource "aws_security_group" "private-ssh" {
  vpc_id      = aws_vpc.aws-cloud.id
  name        = "private-ssh"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [ aws_security_group.ssh_from_internet.id ]
  }
  
  tags = {
    Name = "private-ssh"
  }
}

##SSH Keys to use
resource "aws_key_pair" "bastion_key" {
  key_name   = "bastion_key"
  public_key = file("~/.ssh/id_rsa.pub")
}

##Bastion Server
resource "aws_instance" "bastion_host" {
  #vpc_id                 = aws_vpc.aws-cloud.id
  ami                    = "ami-03f65b8614a860c29"
  instance_type          = "t2.micro"
  subnet_id = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ssh_from_internet.id]
  key_name               = aws_key_pair.bastion_key.key_name
  #vpc_security_group_ids = [aws_security_group.ssh_from_internet.id]
  tags = {
    Name = "Bastion Host"
  }
}

##Print Bastion dns name output
output "bastion_dns" {
  value = aws_instance.bastion_host.public_dns
}
