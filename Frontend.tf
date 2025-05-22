

# 2. Subnet pública
resource "aws_subnet" "react_subnet" {
  vpc_id                  =  aws_vpc.lan-vpc.id 
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "us-east-1a"

  tags = {
    Name = "react-subnet"
  }
}


resource "aws_internet_gateway" "react_igw" {
  vpc_id =  aws_vpc.lan-vpc.id  

  tags = {
    Name = "react-igw"
  }
}


resource "aws_route_table" "react_rt" {
  vpc_id =  aws_vpc.lan-vpc.id  

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.react_igw.id
  }

  tags = {
    Name = "react-rt"
  }
 }

resource "aws_route_table_association" "react_rt_assoc" {
  subnet_id      = aws_subnet.react_subnet.id
  route_table_id = aws_route_table.react_rt.id
}

# 5. Security Group: SSH + Puerto 3000
resource "aws_security_group" "react_sg" {
  name        = "react-sg"
  description = "Permitir SSH y puerto 3000"
  vpc_id      = aws_vpc.lan-vpc.id  

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 3000
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

# 6. EC2 Instance
resource "aws_instance" "react_instance" {
  ami                    = "ami-0440d3b780d96b29d" # Amazon Linux 2023 - us-east-1
  instance_type          = "t3.large"
  subnet_id              = aws_subnet.react_subnet.id
  vpc_security_group_ids = [aws_security_group.react_sg.id]
  key_name               = "WEB"  # Debés tener esta key en AWS EC2

  associate_public_ip_address = true
  user_data = file("scripts/init_front.sh") 

  tags = {
    Name = "react-node"
  }

}

# # 7. Output: IP pública
# output "ip_publica" {
#   value = aws_instance.react_instance.public_ip
# }

# Recurso para la IP Elástica
resource "aws_eip" "mi_ip_elastica_vpc" {
  # vpc      = true # Muy importante: asigna la EIP al ámbito de la VPC

  # Opcional: Asocia la EIP a la instancia EC2 creada anteriormente
  instance = aws_instance.react_instance.id

  tags = {
    Name        = "MiIPElasticaPublica"
    Environment = "Development"
  }
}

# (Opcional) Salida para ver la IP pública asignada
output "elastic_ip_address" {
  description = "La dirección IP elástica asignada."
  value       = aws_eip.mi_ip_elastica_vpc.public_ip
}


