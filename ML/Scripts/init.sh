#!/bin/bash
sudo yum update -y
sudo yum install -y git

python3 -m pip install --upgrade pip
pip3 install pandas numpy holidays scikit-learn psycopg2-binary


# Clona el repositorio en /home/ec2-user
cd /home/ec2-user
git clone https://github.com/Deliverar-Datos/wizard.git

# Cambia permisos para el usuario ec2-user
chown -R ec2-user:ec2-user wizard