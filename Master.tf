provider "aws" {
  region = "us-east-1"  # Cambiá si estás en otra región
}

# 1. Crear la VPC
resource "aws_vpc" "hadoop_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = false
  enable_dns_hostnames = false

  tags = {
    Name = "Hadoop-VPC"
  }
}

# 2. Crear una Subnet /24
resource "aws_subnet" "hadoop_subnet" {
  vpc_id                  = aws_vpc.hadoop_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "us-east-1a" # O cambialo según tu zona

  tags = {
    Name = "Hadoop-Subnet"
  }
}

# 3. Crear una Internet Gateway
resource "aws_internet_gateway" "hadoop_igw" {
  vpc_id = aws_vpc.hadoop_vpc.id

  tags = {
    Name = "Hadoop-IGW"
  }
}

# 4. Crear una tabla de ruteo para salida a internet
resource "aws_route_table" "hadoop_route_table" {
  vpc_id = aws_vpc.hadoop_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.hadoop_igw.id
  }

  tags = {
    Name = "Hadoop-Route-Table"
  }
}

# 5. Asociar la tabla de ruteo con la subnet
resource "aws_route_table_association" "hadoop_rta" {
  subnet_id      = aws_subnet.hadoop_subnet.id
  route_table_id = aws_route_table.hadoop_route_table.id
}

# 6. Crear un Security Group que permita SSH y tráfico interno
resource "aws_security_group" "hadoop_sg" {
  name        = "Hadoop-Nodes-SG"
  description = "Permitirssh"
  vpc_id      = aws_vpc.hadoop_vpc.id

  ingress {
    description = "SSH desde tu IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

    # cidr_blocks = ["YOUR_PUBLIC_IP/32"] # ⚠️ Reemplazar con tu IP pública
  }

  ingress {
    description = "trafico entre nodos"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "Permitir todo el trafico saliente"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Hadoop-SG"
  }
}

# 8. Lanzar una instancia EC2 con la AMI personalizada para el nodo maestro
resource "aws_instance" "hadoop_master" {
  ami                         = "ami-0d2da9010de18c79a"
  instance_type               = "t2.large"
  subnet_id                   = aws_subnet.hadoop_subnet.id
  vpc_security_group_ids      = [aws_security_group.hadoop_sg.id]
  associate_public_ip_address = true
  key_name                    = "hadoop" # ⚠️ Cambiar por tu key pair existente
  private_ip                  = "10.0.1.254"
  user_data = file("init_airflow.sh") # Asumiendo que tienes un script para inicializar PostgreSQL

  
}


# 7. Lanzar una instancia EC2 con la AMI personalizada
resource "aws_instance" "hadoop_node" {
  ami                         = "ami-0ad3aec565f4a8d94"
  count                       = 3
  instance_type               = "t2.large"
  subnet_id                   = aws_subnet.hadoop_subnet.id
  vpc_security_group_ids      = [aws_security_group.hadoop_sg.id]
  associate_public_ip_address = false
  key_name                    = "hadoop" # ⚠️ Cambiar por tu key pair existente
  private_ip                  = "10.0.1.${count.index + 100}"
  

  tags = {
    Name = "datanode0${count.index + 1}"
  }
}



	
