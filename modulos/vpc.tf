resource "aws_vpc" "react_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "react-vpc"
  }
}

output "vpc_id" {
  description = "El ID de la VPC creada."
  value       = aws_vpc.react_vpc.id # Asume que tu recurso VPC se llama 'aws_vpc.main'
}

