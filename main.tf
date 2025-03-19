provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "my-vpc" {
  cidr_block = "172.16.0.0/16"
  tags = {
    Name = "My-VPC"
  }
}

resource "aws_vpc_dhcp_options" "my_dhcp" {
  domain_name         = "allianz.com"
  domain_name_servers = ["AmazonProvidedDNS"]
  #ntp_servers         = ["172.16.16.16", "10.10.10.10"]
  #netbios_name_servers = ["192.168.0.4", "198.168.0.5"]
  #netbios_node_type   = 2

  tags = {
    Name = "My-DHCP-Options"
  }
}

resource "aws_vpc_dhcp_options_association" "my_dhcp_assoc" {
  vpc_id          = aws_vpc.my-vpc.id
  dhcp_options_id = aws_vpc_dhcp_options.my_dhcp.id
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = "172.16.1.0/24"
  map_public_ip_on_launch = true
}

resource "aws_security_group" "my-sg" {
  vpc_id = aws_vpc.my-vpc.id 

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

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.my-vpc.id
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_instance" "web-server" {
  ami             = "ami-04b4f1a9cf54c11d0"
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.public.id
  security_groups = [aws_security_group.my-sg.id]
  key_name        = "MyKeyPair"

  tags = {
    Name = "Web-Server"
  }

  user_data = <<-EOF
    #!/bin/bash
    sleep 60
    sudo apt update -y
    sudo apt install -y apache2
    sudo systemctl start apache2
    sudo systemctl enable apache2
  EOF
}

output "Web-Server-URL" {
  value = "http://${aws_instance.web-server.public_ip}"
}
