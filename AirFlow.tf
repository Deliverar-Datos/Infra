resource "aws_vpc" "lan-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "react-vpc"
  }
}

output "vpc_id" {
  description = "El ID de la VPC creada."
  value       = aws_vpc.lan-vpc .id # Asume que tu recurso VPC se llama 'aws_vpc.main'
}


# 2. Subnet pública
resource "aws_subnet" "airflow_subnet" {
  vpc_id                  = aws_vpc.lan-vpc.id 
  cidr_block              = "10.0.4.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "us-east-1a"

  tags = {
    Name = "airflow-subnet"
  }
}

# 3. Internet Gateway
resource "aws_internet_gateway" "airflow_igw" {
  vpc_id = aws_vpc.lan-vpc.id  # Correcto

  tags = {
    Name = "airflow-igw"
  }
}

# 4. Tabla de rutas
resource "aws_route_table" "airflow_rt" {
  vpc_id = aws_vpc.lan-vpc.id  # ¡CORREGIDO! Debe ser airflow_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.airflow_igw.id
  }

  tags = {
    Name = "airflow-rt"
  }
}

resource "aws_route_table_association" "airflow_rt_assoc" {
  subnet_id      = aws_subnet.airflow_subnet.id
  route_table_id = aws_route_table.airflow_rt.id
}

# 5. Security Group: SSH + Puertos de Airflow
resource "aws_security_group" "airflow_sg" {
  name        = "airflow-sg"
  description = "Permitir SSH y puertos de Airflow"
  vpc_id      = aws_vpc.lan-vpc.id  # ¡CORREGIDO! Debe ser airflow_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH Access"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Airflow Webserver"
  }

 ingress {
    from_port   = 443  
    to_port     = 443 
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Airflow Webserver"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "airflow-sg"
  }
}

# 6. EC2 Instance para Airflow
resource "aws_instance" "airflow_instance" {
  ami                    = "ami-0440d3b780d96b29d"
  instance_type          = "t2.large"
  subnet_id              = aws_subnet.airflow_subnet.id
  vpc_security_group_ids = [aws_security_group.airflow_sg.id]
  key_name               = "WEB"
  user_data = file("scripts/init-docker-airflow.sh")

  associate_public_ip_address = true

  tags = {
    Name = "airflow-node"
    Role = "AirflowWebserverScheduler"
  }
}

# Recurso para la IP Elástica
resource "aws_eip" "airflow_elastic_ip" {
  instance = aws_instance.airflow_instance.id

  tags = {
    Name        = "AirflowPublicIP"
    Environment = "Development"
  }
}

# Salida para ver la IP pública asignada
output "airflow_public_ip_address" {
  description = "La dirección IP elástica asignada para la instancia de Airflow."
  value       = aws_eip.airflow_elastic_ip.public_ip
}
