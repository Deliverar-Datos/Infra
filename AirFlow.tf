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
  value       = aws_vpc.lan-vpc.id # Asume que tu recurso VPC se llama 'aws_vpc.main'
}

data "aws_eip" "ipairlow" {
  id = "eipalloc-0f78a92ea0ba06992" # ¡REEMPLAZA CON EL ID DE TU EIP EXISTENTE!
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
  key_name                = "hadoop" 
  user_data = file("scripts/init-docker-airflow.sh")

  associate_public_ip_address = false

  tags = {
    Name = "airflow-node"
    Role = "AirflowWebserverScheduler"
  }
}

# Recurso para la IP Elástica


resource "aws_eip_association" "web_instance_association_airflow" {
  instance_id   = aws_instance.airflow_instance.id # ID de tu instancia EC2
  allocation_id = data.aws_eip.ipairlow.id # O data.aws_eip.existing_eip_by_id.id
}