#!/bin/bash

PORT = 80 # Puerto para servir la aplicación (requiere configuración adicional para no-root)
DOMAIN = "airflow.deliver.ar" # Dominio para el servidor Nginx
APP_NAME = 'airflow'


set -e # Salir inmediatamente si un comando falla

# 1. Actualizar el sistema e instalar herramientas básicas
echo "--- Actualizando el sistema e instalando herramientas ---"
sudo yum update -y
sudo yum install -y git # Puede ser útil para clonar DAGs o configuraciones
sudo yum install -y unzip # Necesario para descomprimir binarios si se descargan así

# 2. Instalar Docker
echo "--- Instalando Docker ---"
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user # Añadir ec2-user al grupo docker

# 3. Instalar Docker Compose
# Amazon Linux 2023 puede no tener docker-compose en los repositorios por defecto
# Descargamos directamente el binario
echo "--- Instalando Docker Compose ---"
DOCKER_COMPOSE_VERSION="2.27.0" # Puedes ajustar la versión si es necesario
sudo curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
# Crear un enlace simbólico si docker-compose no funciona directamente
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose || true

# Verificar instalación
docker --version
docker-compose --version

# 4. Configuración de Airflow
echo "--- Configurando directorios y descargando docker-compose de Airflow ---"
AIRFLOW_HOME="/opt/airflow"
sudo mkdir -p ${AIRFLOW_HOME}/dags
sudo mkdir -p ${AIRFLOW_HOME}/logs
sudo mkdir -p ${AIRFLOW_HOME}/plugins
sudo chown -R ec2-user:ec2-user ${AIRFLOW_HOME} # Dar permisos al usuario ec2-user

cd ${AIRFLOW_HOME}

# Descargar docker-compose.yaml oficial de Airflow
# Para versiones estables y recomendadas, puedes ir a la documentación oficial de Airflow
# y obtener el enlace directo al docker-compose.yaml.
# Este enlace es para la última versión en el momento de escribir esto.
# Consulta: https://airflow.apache.org/docs/apache-airflow/stable/howto/docker-compose/index.html
AIRFLOW_VERSION="2.9.1" # Define la versión de Airflow que quieres
curl -LfO "https://airflow.apache.org/docs/apache-airflow/${AIRFLOW_VERSION}/docker-compose.yaml"

# Generar la clave secreta de Airflow (fundamental para la seguridad)
echo "--- Generando clave secreta de Airflow ---"
# Espera a que el usuario ec2-user sea parte del grupo docker
# Esto es crucial ya que el comando 'docker-compose' necesita permisos de docker
# A veces, el usermod necesita un relogin, pero en user_data, el script continúa.
# Una forma de asegurar es añadir un pequeño delay o ejecutar un 'newgrp docker'
# Aquí asumimos que para el momento de docker-compose, el permiso ya está activo.
# Si tienes problemas, considera reiniciar la instancia después del paso 3.
# Alternativa: Ejecutar comandos de docker-compose con 'sudo' o 'sg docker -c "..."'

# Comando para generar una clave secreta (usando Python para aleatoriedad)
# Ejecutar esto dentro del contenedor airflow-cli es lo más limpio
# Primero, necesitamos que los contenedores estén al menos en un estado básico
# para ejecutar comandos dentro de ellos.
# Alternativa más simple para user_data: generar localmente y usar en .env
AIRFLOW_UID=$(id -u)
echo "AIRFLOW_UID=${AIRFLOW_UID}" >> .env

# Generar clave secreta directamente en el script e insertarla en el .env
# Esto es más seguro que dejarla en el user_data de forma literal
echo "--- Generando y configurando AIRFLOW_WEBSERVER_SECRET_KEY ---"
SECRET_KEY=$(python3 -c 'import secrets; print(secrets.token_hex(16))')
echo "AIRFLOW_WEBSERVER_SECRET_KEY=${SECRET_KEY}" >> .env

# El .env también es un buen lugar para definir la versión de Airflow y el usuario/contraseña
echo "AIRFLOW_VERSION=${AIRFLOW_VERSION}" >> .env
echo "POSTGRES_USER=airflow" >> .env
echo "POSTGRES_PASSWORD=airflow" >> .env
echo "POSTGRES_DB=airflow" >> .env
echo "POSTGRES_PORT=5432" >> .env
echo "POSTGRES_HOST=postgres" >> .env


# 5. Inicializar la base de datos de Airflow
echo "--- Inicializando la base de datos de Airflow ---"
# Es necesario que el contenedor postgres esté en marcha para esto
# docker-compose up -d postgres # Solo levantar la DB y luego ejecutar initdb

# Airflow 2.x ya incluye la inicialización de la DB en el startup si no existe.
# Sin embargo, para mayor control, podemos forzarla antes de levantar todo.
# Primero, aseguramos que el usuario ec2-user pueda usar docker-compose
# La mejor forma es asegurarse que la sesión de user_data tenga el grupo docker activo.
# O, reiniciar la instancia después de instalar docker y agregar el usuario al grupo.
# Para user_data sin reinicio, a veces 'sudo' es la opción más robusta.

# Usaremos un método que levante el contenedor temporalmente para la inicialización
# Esto es importante porque el grupo docker no se activa en la sesión del user_data
# hasta que el usuario se loguea de nuevo. Por eso, usamos 'sudo -E' (mantener env)
# o simplemente 'sudo docker-compose'.
sudo docker-compose up -d postgres

# Esperar a que la base de datos esté lista (ajusta el sleep si es necesario)
echo "Esperando 15 segundos para que PostgreSQL inicie..."
sleep 15

# Inicializar la base de datos usando el contenedor cli de Airflow
sudo docker-compose run --rm airflow-cli airflow db migrate

# Crear el usuario administrador de Airflow
echo "--- Creando usuario administrador de Airflow ---"
sudo docker-compose run --rm airflow-cli airflow users create \
    --username admin \
    --firstname Airflow \
    --lastname Admin \
    --role Admin \
    --email admin@example.com \
    --password admin

# 6. Levantar los servicios de Airflow
echo "--- Levantando todos los servicios de Airflow ---"
sudo docker-compose up -d

echo "--- Script de inicialización de Airflow completado ---"
echo "El Webserver de Airflow debería estar accesible en la IP pública de la instancia en el puerto 8080."
echo "Usuario: admin, Contraseña: admin"



# 7. Instalar Nginx y Certbot
echo "--- Instalando Nginx y Certbot ---"
sudo yum install -y nginx # Instalar Nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Instalar Certbot y el plugin de Nginx
#sudo yum install -y epel-release # Para instalar Certbot desde un repo extra
sudo yum install -y certbot python3-certbot-nginx

# 8. Configurar Nginx como proxy inverso para Airflow
echo "--- Configurando Nginx como proxy inverso ---"
# Crear el archivo de configuración de Nginx
# sudo bash -c "cat > /etc/nginx/conf.d/airflow.conf <<EOL
# server {
#     listen 80;
#     server_name ${DOMAIN};
#     return 301 https://\$host\$request_uri; # Redirigir HTTP a HTTPS
# }

# server {
#     listen 443 ssl;
#     server_name ${DOMAIN};

#     ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
#     ssl_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;

#     ssl_session_cache shared:SSL:10m;
#     ssl_session_timeout 10m;
#     ssl_protocols TLSv1.2 TLSv1.3;
#     ssl_ciphers 'TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384';
#     ssl_prefer_server_ciphers on;

#     # Ajustes para Airflow (basado en la documentación oficial)
#     proxy_set_header Host \$host;
#     proxy_set_header X-Real-IP \$remote_addr;
#     proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
#     proxy_set_header X-Forwarded-Proto \$scheme;
#     proxy_redirect http:// \$scheme://;
#     proxy_buffering off;
#     proxy_request_buffering off;

#     # La URL interna del webserver de Airflow en Docker Compose
#     # Si Nginx corre en la misma máquina que docker-compose, 'localhost' es suficiente
#     location / {
#         proxy_pass http://localhost:8080; # Puerto interno del contenedor de Airflow
#     }

#     # Proxy para websockets (para logs en tiempo real)
#     location /ws/ {
#         proxy_pass http://localhost:8080/ws/;
#         proxy_http_version 1.1;
#         proxy_set_header Upgrade \$http_upgrade;
#         proxy_set_header Connection "upgrade";
#     }

#     # Bloquear el acceso a archivos de configuración sensibles
#     location ~ /\. {
#         deny all;
#         return 404;
#     }
# }
# EOL"

# Verificar la configuración de Nginx y recargar
sudo nginx -t
sudo systemctl reload nginx

# 9. Obtener Certificado SSL con Certbot
echo "--- Obteniendo certificado SSL con Certbot ---"
# Primero, detener Nginx para que Certbot pueda usar el puerto 80 para el desafío http-01
sudo systemctl stop nginx
sleep 5 # Pequeña espera para asegurar que Nginx se detuvo

# Ejecutar Certbot (usando --nginx plugin para que configure Nginx automáticamente)
# Pero dado que ya creamos la config manual, usaremos --webroot
# sudo certbot certonly --webroot -w /usr/share/nginx/html -d ${DOMAIN} --email ${EMAIL} --agree-tos --no-eff-email

# Volver a iniciar Nginx
sudo systemctl start nginx

# 10. Levantar el webserver de Airflow
echo "--- Levantando el webserver de Airflow ---"
#sudo docker-compose up -d webserver

# 11. Configurar renovación automática de Certbot
echo "--- Configurando renovación automática de Certbot ---"
# Certbot ya instala un cronjob o un timer de systemd para la renovación.
# Puedes probarlo con:
# sudo certbot renew --dry-run
# Para Amazon Linux 2023, suele venir como un timer de systemd:
# systemctl list-timers | grep certbot
# Asegúrate de que el timer exista y esté habilitado si quieres verificarlo.
# sudo systemctl enable certbot-renew.timer
# sudo systemctl start certbot-renew.timer # Para probar que el timer funciona


echo "--- Script de inicialización de Airflow con SSL completado ---"
echo "El Webserver de Airflow debería estar accesible en https://${DOMAIN} en el puerto 443."
echo "Usuario: admin, Contraseña: admin"


configure_nginx() {
  info "Configurando Nginx para servir la aplicación React..."
  #sudo rm /etc/nginx/conf.d/default.conf
  sudo tee /etc/nginx/conf.d/$APP_NAME.conf > /dev/null <<EOF
server {
    listen $PORT;
    server_name tableros.deliver.ar; # Puedes reemplazar _ con tu dominio si lo tienes

    location / {
    proxy_pass http://127.0.0.1:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }

  }
EOF
  if [ $? -ne 0 ]; then
    error "Error al configurar Nginx."
    exit 1
  fi
  success "Nginx configurado."
}

start_nginx() {
  info "Iniciando y habilitando Nginx..."
  sudo systemctl start nginx
  sudo systemctl enable nginx
  sudo systemctl status nginx
  if [ $? -ne 0 ]; then
    error "Error al iniciar o habilitar Nginx."
    exit 1
  fi
  success "Nginx iniciado y habilitado."
}

cert(){
   sleep 10 
   sudo certbot --nginx -d airflow.deliver.ar --email bautistafantauzzo@gmail.com --agree-tos --non-interactive --redirect
}
main() {
  
  configure_nginx
  start_nginx
  cert

  echo -e "\n\e[1;32m¡Aplicación React desplegada exitosamente en http://<Tu_IP_EC2>:$PORT!\e[0m"
  echo -e "\e[1;33mRecuerda configurar un nombre de dominio y HTTPS para un entorno de producción real.\e[0m"
}

main "$@"