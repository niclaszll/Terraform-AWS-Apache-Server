# vars
variable "aws_access_key" {
  description = "your AWS access key"
  type        = string
  sensitive   = true
}

variable "aws_secret_key" {
  description = "your AWS secret key"
  type        = string
  sensitive   = true
}

variable "ssh_key_name" {
  description = "your SSH key name"
  type        = string
}

variable "subnet_prefix" {
  description = "cider block for subnet"
  type = string
  default = "10.0.100.0/24"
}

# configure AWS provider
provider "aws" {
  region = "us-east-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

# 1. create vpc
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "production"
  }
}

# 2. create internet gateway
resource "aws_internet_gateway" "prod-gw" {
  vpc_id = aws_vpc.prod-vpc.id
}

# 3. create custom route table
resource "aws_route_table" "prod-routetable" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod-gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.prod-gw.id
  }

  tags = {
    Name = "production"
  }
}

# 4. create subnet
resource "aws_subnet" "prod-subnet" {
  vpc_id     = aws_vpc.prod-vpc.id
  cidr_block = var.subnet_prefix
  availability_zone = "us-east-1a"

  tags = {
    Name = "production"
  }
}

# 5. associate subnet with route table
resource "aws_route_table_association" "prod-route-table-association" {
  subnet_id      = aws_subnet.prod-subnet.id
  route_table_id = aws_route_table.prod-routetable.id
}

# 6. create security group for port 22, 80, 443
resource "aws_security_group" "allow_web" {
  name        = "allow_web"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
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
    Name = "allow_web"
  }
}

# 7. create network interface with an ip in the subnet
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.prod-subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

# 8. assign elastic ip to network interface
resource "aws_eip" "prod-elastic-ip" {
  network_interface = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  vpc      = true
  depends_on = [aws_internet_gateway.prod-gw]
}

# 9. deploy ubuntu web server
resource "aws_instance" "prod-server" {
  ami           = "ami-042e8287309f5df03"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = var.ssh_key_name

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo Hello World > /var/www/html/index.html'
              EOF

  tags = {
    Name = "prod-ec2-ubuntu"
  }
}

# output public ip of deployed server
output "server_public_ip" {
  value = aws_eip.prod-elastic-ip.public_ip
}