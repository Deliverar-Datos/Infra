#!/bin/bash -xe

echo "⏳ Iniciando instalación de PostgreSQL 13 en Amazon Linux 2023..."

# Parámetros
USERNAME="integracion"
PASSWORD="gatopardo123"
DATABASE_NAME="deliverar_db"

# Instalar PostgreSQL desde repositorios oficiales de Amazon Linux 2023
sudo yum install -y postgresql17-server.x86_64 postgresql17.x86_64
# Inicializar la base de datos
sudo postgresql-setup --initdb

# Habilitar e iniciar el servicio
sudo systemctl enable postgresql
sudo systemctl start postgresql

# Esperar a que esté activo
sleep 5

# Crear usuario y base de datos
sudo -u postgres psql <<EOF
DO \$\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '$USERNAME') THEN
      CREATE ROLE $USERNAME WITH LOGIN PASSWORD '$PASSWORD';
      ALTER ROLE $USERNAME WITH SUPERUSER;
   END IF;
END
\$\$;

CREATE DATABASE $DATABASE_NAME OWNER $USERNAME;
EOF

# Permitir conexiones remotas (modificar postgresql.conf y pg_hba.conf)
PG_CONF="/var/lib/pgsql/data/postgresql.conf"

HBA_CONF="/var/lib/pgsql/data/pg_hba.conf"

# Escuchar en todas las interfaces
sudo sed -i "s/^#listen_addresses = 'localhost'/listen_addresses = '*'/g" $PG_CONF
# Agregar regla de acceso al final de pg_hba.conf
echo "host    all             all             0.0.0.0/0               md5" | sudo tee -a $HBA_CONF

# Reiniciar para aplicar cambios
sudo systemctl restart postgresql.service

echo "✅ PostgreSQL 17 instalado y configurado para aceptar conexiones remotas."