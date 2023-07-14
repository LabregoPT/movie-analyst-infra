## ------------------------------------
## Cloud Keys Definition
## ------------------------------------
## This file holds the configuration and definition of cloud key resources
## AKA, here are the configurations for the SSH keys used to SSH into servers

## AWS Key
resource "aws_key_pair" "bastion_key" {
  key_name   = "bastion_key"
  public_key = file("~/.ssh/id_rsa.pub")
}