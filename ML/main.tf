

# # VPC principal para backend EC2
# resource "aws_vpc" "main" {
#   cidr_block           = "10.0.0.0/16"
#   enable_dns_support   = true
#   enable_dns_hostnames = true

#   tags = {
#     Name = "hadoop-vpc"
#   }
# }
# deploy/main.tf
module "vpc" {
  source = "../modulos"
}


resource "aws_subnet" "main" {
  vpc_id                  = module.vpc.vpc_id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1c"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "gw" {
  vpc_id = module.vpc.vpc_id
}

resource "aws_route_table" "rt" {
  vpc_id = module.vpc.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "backend_sg" {
  name        = "backend-sg"
  description = "Allow SSH and Git access"
  vpc_id      = module.vpc.vpc_id

  ingress {
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
    Name = "backend-sg"
  }
}

# Instancia EC2 para ejecutar el backend con git clone
resource "aws_instance" "backend" {
  ami                         = "ami-0c02fb55956c7d316" # Amazon Linux 2 AMI para us-east-1
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.main.id
  vpc_security_group_ids      = [aws_security_group.backend_sg.id]
  associate_public_ip_address = true


  user_data = file("scripts/init.sh")

  tags = {
    Name = "backend-ec2"
  }
}

output "backend_instance_ip" {
  value = aws_instance.backend.public_ip
} 
