



resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.lan-vpc.id  
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1c"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.lan-vpc.id  
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.lan-vpc.id  

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
  vpc_id      = aws_vpc.lan-vpc.id  

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
  user_data = file("scripts/init_ML.sh")

  tags = {
    Name = "backend-ec2"
  }
}

output "backend_instance_ip" {
  value = aws_instance.backend.public_ip
} 
