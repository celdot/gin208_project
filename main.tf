# Configure aws provider
provider "aws" {
  region = var.region
}

# Read vpc resource 
data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Name"
    values = var.vpc_name
  }
}

### Create 2 subnets

# Create public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id     = data.aws_vpc.vpc.id
  cidr_block = var.cidr_block_public

  tags = {
    Name = var.public_subnet
  }
}

#Create private subnet
resource "aws_subnet" "private_subnet" {
  vpc_id     = data.aws_vpc.vpc.id
  cidr_block = var.cidr_block_private

  tags = {
    Name = var.private_subnet
  }
}

### Create a routing table

# Create internet gateaway
resource "aws_internet_gateway" "gw" {
  vpc_id = data.aws_vpc.vpc.id

  tags = {
    Name = var.gw_name
    Group = var.group
  }
}

#create route table
resource "aws_route_table" "rtb" {
  vpc_id = data.aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = var.rtb_name
    Group = var.group
  }
}

#Create route table association
resource "aws_route_table_association" "public-association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.rtb.id
}

#Create route table association
resource "aws_route_table_association" "private-association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.rtb.id
}

### Create a security group

#Create security group to allow some traffic in the frontend VM
resource "aws_security_group" "allow_traffic_frontend" {
  name        = "Allow_traffic frontend"
  description = "Allow some inbound traffic (443, SSH) and all outbound traffic"
  vpc_id      = data.aws_vpc.vpc.id

  tags = {
    Name = var.sg_name
    Group = var.group
  }
}

#Create security group to allow ssh for ipv4 from outside
resource "aws_vpc_security_group_ingress_rule" "allow_ssh_ipv4_fe" {
  security_group_id = aws_security_group.allow_traffic_frontend.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

#Create security group to allow external connections on port 80
resource "aws_vpc_security_group_ingress_rule" "allow_port_80_fe" {
  security_group_id = aws_security_group.allow_traffic_frontend.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

#Create security group to allow external connections on port 443
resource "aws_vpc_security_group_ingress_rule" "allow_port_443_fe" {
  security_group_id = aws_security_group.allow_traffic_frontend.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

#Create security group to allow external connections on port 1943 but only from our backend (subnet)
resource "aws_vpc_security_group_ingress_rule" "allow_port_1943_fe" {
  security_group_id = aws_security_group.allow_traffic_frontend.id
  cidr_ipv4         = var.cidr_block_private
  from_port         = 1943
  ip_protocol       = "tcp"
  to_port           = 1943
}

#Create security group to allow any ipv4 to the outside
resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4_fe" {
  security_group_id = aws_security_group.allow_traffic_frontend.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

####### #######

#Create security group to allow some traffic in the backend VM
resource "aws_security_group" "allow_traffic_backend" {
  name        = "Allow_traffic backend"
  description = "Allow some inbound traffic (SSH) and all outbound traffic"
  vpc_id      = data.aws_vpc.vpc.id

  tags = {
    Name = var.sg_name
    Group = var.group
  }
}

#Create security group to allow ssh for ipv4 only from our frontend (own subnet)
resource "aws_vpc_security_group_ingress_rule" "allow_ssh_ipv4_be" {
  security_group_id = aws_security_group.allow_traffic_backend.id
  cidr_ipv4         = var.cidr_block_public
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

#Create security group to allow external connections on port 1943 but only from our frontend
resource "aws_vpc_security_group_ingress_rule" "allow_port_1943_be" {
  security_group_id = aws_security_group.allow_traffic_backend.id
  cidr_ipv4         = var.cidr_block_public
  from_port         = 1943
  ip_protocol       = "tcp"
  to_port           = 1943
}

#Create security group to allow any ipv4 to the outside
resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4_be" {
  security_group_id = aws_security_group.allow_traffic_backend.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

### Create key pair

# for frontend

# Generate RSA key of size 4096 bits
resource "tls_private_key" "rsa-4096-fe" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create local file to to save the content private_key_pem of the tls_private_key resource
resource "local_file" "key_file_fe" {
  content  = tls_private_key.rsa-4096-fe.private_key_pem
  filename = var.key_path_fe
}

resource "aws_key_pair" "deployer_fe" {
  key_name   = var.key_name_fe
  public_key = tls_private_key.rsa-4096-fe.public_key_openssh

  tags = {
    Name = var.key_name_fe
  }
}

#### #### Same for backend

# Generate RSA key of size 4096 bits
resource "tls_private_key" "rsa-4096-be" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create local file to to save the content private_key_pem of the tls_private_key resource
resource "local_file" "key_file_be" {
  content  = tls_private_key.rsa-4096-be.private_key_pem
  filename = var.key_path_be
}

resource "aws_key_pair" "deployer_be" {
  key_name   = var.key_name_be
  public_key = tls_private_key.rsa-4096-be.public_key_openssh

  tags = {
    Name = var.key_name_be
  }
}

### Create 2 EC2 instances

# Create AMI (read resource)
data "aws_ami" "ubuntu_ami" {
  most_recent = true

  filter {
    name = "name"
    values = var.ami_name
  }
  
}

# Create the instance for the frontend
resource "aws_instance" "frontend-vm" {
  ami                         = data.aws_ami.ubuntu_ami.id
  instance_type               = var.instance_type
  subnet_id = aws_subnet.public_subnet.id

  associate_public_ip_address = true
  source_dest_check = false

  key_name                    = aws_key_pair.deployer_fe.key_name

  security_groups             = [aws_security_group.allow_traffic_frontend.id]

  tags = {
    Name = var.frontend_instance
    Group = var.group
  }
}

# Create the instance for the backend
resource "aws_instance" "backend-vm" {
  ami                         = data.aws_ami.ubuntu_ami.id
  instance_type               = var.instance_type
  subnet_id = aws_subnet.private_subnet.id

  associate_public_ip_address = true
  source_dest_check = false

  key_name                    = aws_key_pair.deployer_be.key_name

  security_groups             = [aws_security_group.allow_traffic_backend.id]

  tags = {
    Name = var.backend_instance
    Group = var.group
  }
}

### Capture the public ip of the ec2 instances in output variable

# Capture the public ip of the frontend instance
output "instance_public_ip_adress_frontend" {
  value = aws_instance.frontend-vm.public_ip
}

# Capture the public ip of the backend instance
output "instance_public_ip_adress_backend" {
  value = aws_instance.backend-vm.public_ip
}

# Capture the private ip of the frontend instance
output "instance_private_ip_adress_frontend" {
  value = aws_instance.frontend-vm.private_ip
}

# Capture the private ip of the backend instance
output "instance_private_ip_adress_backend" {
  value = aws_instance.backend-vm.private_ip
}