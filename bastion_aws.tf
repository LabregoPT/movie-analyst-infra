
#-------------------------
# Bastion Host Configuration
#-------------------------

# route tables
resource "aws_route_table" "main-public" {
  vpc_id = aws_vpc.aws-cloud.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway.id
  }
  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gateway.id
  }
  tags = {
    Name = "main-public"
  }
}

resource "aws_route_table_association" "main-public-1-a" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.main-public.id
}

resource "aws_route_table_association" "main-public-2-a" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.main-public.id
}

##Security Groups
resource "aws_security_group" "ssh_from_internet" {
  vpc_id      = aws_vpc.aws-cloud.id
  name        = "ssh_from_internet"
  description = "Used to allow SSH from any IP into Bastion Host"
  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    name = "public-ssh"
  }
}

resource "aws_security_group" "private_ssh" {
  vpc_id      = aws_vpc.aws-cloud.id
  name        = "ssh_from_baston"
  description = "Used to allow SSH from Bastion into any resource"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.ssh_from_internet.id]
  }
  tags = {
    Name = "ssh_from_baston"
  }
}

##Bastion Server
resource "aws_instance" "bastion_host" {
  ami                    = "ami-0c65adc9a5c1b5d7c"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet_1.id
  vpc_security_group_ids = [aws_security_group.ssh_from_internet.id]
  key_name               = aws_key_pair.bastion_key.key_name
  tags = {
    Name = "Bastion Host"
  }
}

##Print Bastion dns name output
output "bastion_dns" {
  value = aws_instance.bastion_host.public_dns
}
output "server1_dns" {
  value = aws_instance.server_1.public_dns
}
output "server2_dns" {
  value = aws_instance.server_2.public_dns
}
output "alb_dns" {
  value = aws_lb.load_balancer.dns_name
}
