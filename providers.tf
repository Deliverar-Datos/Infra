resource "aws_instance" "maquina_basica" {
  ami           = "ami-0f88e80871fd81e91" # ¡AMI actualizada!
  instance_type = "t2.micro"
  tags = {
    Name = "maquina-basica"
  }
}