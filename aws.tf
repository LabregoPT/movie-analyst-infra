resource "aws_vpc" "aws-cloud" {
  #Main AWS Cloud network
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "gw" {
  #Required to allow access from outside the VPC

  vpc_id = aws_vpc.aws-cloud.id

  tags = {
    Name = "main"
  }
}
