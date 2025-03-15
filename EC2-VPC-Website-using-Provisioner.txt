terraform {
    required_providers {
        aws = {
        source = "hashicorp/aws"
        version = "~>5.0"
        }
    }
}

provider "aws" {
    region = "us-east-1"
}


    
resource "aws_vpc" "my-vpc" {
    cidr_block = "172.16.0.0/16"
    tags = {
        Name = "my-vpc"
    }
    
}  

resource "aws_security_group" "web-sg" {
    vpc_id = aws_vpc.my-vpc.id

    dynamic "ingress" {
        for_each = [22, 80, 443]
        content {
            from_port   = ingress.value
            to_port     = ingress.value
            protocol    = "tcp"
            cidr_blocks = ["0.0.0.0/0"]
        }
    }

    egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_subnet" "Public-Subnet" {
    vpc_id = aws_vpc.my-vpc.id
    cidr_block = "172.16.1.0/24"
    map_public_ip_on_launch = true
    availability_zone = "us-east-1a"
    tags = {
        Name = "Public-Subnet"
    }
}

resource "aws_subnet" "Private-Subnet" {
    vpc_id = aws_vpc.my-vpc.id
    cidr_block = "172.16.2.0/24"
    map_public_ip_on_launch = false
    availability_zone = "us-east-1b"
    tags = {
        Name = "Private-Subnet"
    }
}

resource  "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.my-vpc.id
    tags = {
        Name = "My-Internet_Gateway"
    }

}

resource "aws_route_table" "my-rt" {
    vpc_id = aws_vpc.my-vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }

    tags = {
        Name = "My-Public-Route-table"
    }

}

resource "aws_route_table_association" "Public-Association" {
    route_table_id = aws_route_table.my-rt.id
    subnet_id = aws_subnet.Public-Subnet.id
}


data "aws_ami" "latest" {

    most_recent = true
    owners = ["amazon"]
    
}

resource "aws_key_pair" "mykey" {
  key_name   = "mykey"
  public_key = file("C:/Users/cchak/.ssh/mykey.pub")
}

resource "aws_instance" "Web-Server" {
    ami                    = data.aws_ami.latest.id
    instance_type          = "t2.micro"
    subnet_id              = aws_subnet.Public-Subnet.id
    vpc_security_group_ids = [aws_security_group.web-sg.id]
    associate_public_ip_address = true
    key_name               = aws_key_pair.mykey.key_name

    tags = {
        Name        = "Web-Server"
        Environment = "Development"
    }

    # Create /var/www/html directory with correct permissions
    provisioner "remote-exec" {
        inline = [
            "sudo mkdir -p /var/www/html",
            "sudo chown -R ubuntu:ubuntu /var/www/html",
            "sudo chmod -R 755 /var/www/html",
            "sudo apt update -y",
            "sudo apt install -y nginx",
            "sudo systemctl enable nginx",
            "sudo systemctl start nginx"
            
        ]
    }

    # Use file provisioner to upload index.html
    provisioner "file" {
        source      = "./index.html"
        destination = "/home/ubuntu/index.html"
    }

    # Move file to /var/www/html/ with sudo (as ubuntu user cannot write there directly)
    provisioner "remote-exec" {
        inline = [
            "sudo mv /home/ubuntu/index.html /var/www/html/index.html",
            "sudo systemctl restart nginx"
        ]
    }

    connection {
        type        = "ssh"
        user        = "ubuntu"
        private_key = file("C:/Users/cchak/.ssh/mykey.pem")
        host        = self.public_ip
    }
}
