

resource "aws_instance" "postgres" {
 # source        = "../modules/ec2_app/"
  ami           = "ami-0f88e80871fd81e91" # Amazon Linux 2 AMI (us-east-1). ¡Verifica la AMI más reciente para tu región!
  key_name      = "WEB" # Usa el nombre que elegiste al importar la clave
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.postgres_sg.id]
  associate_public_ip_address = true
  # vpc_id        = module.app_vpc.outputs.vpc_id # Pasa el ID de la VPC
  subnet_id     = aws_vpc.lan-vpc.id  # Pasa el ID de la primera subred pública




tags = {
    Name        = "ServidorPostgreSQL"
    Environment = "Produccion"
    Application = "MiAplicacion"
    Database    = "PostgreSQL"
    Version     = "15.x" # Ejemplo de versión de PostgreSQL
    Backup      = "Semanal"
    Owner       = "EquipoDeBD"
  }

  user_data = file("scripts/init_postgres.sh") # Asumiendo que tienes un script para inicializar PostgreSQL
}

resource "aws_security_group" "postgres_sg" {
  name_prefix = "postgres-sg-"
  vpc_id      = aws_vpc.lan-vpc.id    # ← Esto es lo que faltaba


  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # ¡Precaución! Considera restringir el acceso
  }

   # Regla para SSH (puerto 22 por defecto, o el puerto que hayas configurado)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # ¡Reemplaza con tu dirección IP o un rango específico!
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "SecurityGroupPostgreSQL"
    Environment = "Produccion"
    Application = "MiAplicacion"
    Database    = "PostgreSQL"
  }
}


resource "aws_subnet" "mi_subnet_publica" {
  vpc_id            = aws_vpc.lan-vpc.id 
  cidr_block        = "10.0.8.0/24" # Rango de direcciones IP para la subred pública
  availability_zone = "us-east-1a"   # Elige tu Availability Zone

  tags = {
    Name = "mi-subnet-publica-terraform"
  }
}

resource "aws_internet_gateway" "mi_igw" {
  vpc_id = aws_vpc.lan-vpc.id  

  tags = {
    Name = "mi-igw-terraform"
  }
}

resource "aws_route_table" "mi_rt_publica" {
  vpc_id = aws_vpc.lan-vpc.id  

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mi_igw.id
  }

  tags = {
    Name = "mi-rt-publica-terraform"
  }
}

resource "aws_route_table_association" "mi_asociacion_publica" {
  subnet_id      = aws_subnet.mi_subnet_publica.id
  route_table_id = aws_route_table.mi_rt_publica.id
}

output "ip_publica_postgres" {
  value = aws_instance.postgres.public_ip
}