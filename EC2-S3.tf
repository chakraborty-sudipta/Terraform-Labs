terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "5.54.1"
        }
        random ={
            source = "hashicorp/random"
            version = "3.6.2"
    }
    }
backend "s3"{
    bucket = "sambit-chakraborty-14-03-2025"
    key = "terraform.tfstate"
    region = "us-east-1"
}
}



provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "myserver" {
    ami = var.ami
    instance_type = "t2.micro"
    tags = {
      
      Name= "ec2-demo"
      }
    }
  
resource "random_id" "rand_id" {
  byte_length = 8
}

resource "aws_s3_bucket" "bucket" {
    bucket = "sambit-chakraborty-${random_id.rand_id.hex}"
}

resource "aws_s3_object" "myfile" {
    bucket = aws_s3_bucket.bucket.id
    source = "./myresource.txt"
    key = "myresource.txt"
}

output "my-output" {
  value = "Public IP address of the EC2 instance is: ${aws_instance.myserver.public_ip}"
}

output "s3-bucket" {
  value = random_id.rand_id.hex
}


Variable.tf 

variable "ami" {
    default = "ami-04b4f1a9cf54c11d0"
    
}

