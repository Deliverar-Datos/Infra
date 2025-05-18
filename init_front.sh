
#!/bin/bash

# Variables de configuración
APP_NAME="mi-app-react"
NODE_VERSION="17" # Versión LTS recomendada para producción
USER="ec2-user"   # Usuario por defecto en Amazon Linux 2
PORT="80"         # Puerto para servir la aplicación (requiere configuración adicional para no-root)

info() {
  echo -e "\e[1;34m[INFO] $1\e[0m"
}

success() {
  echo -e "\e[1;32m[OK] $1\e[0m"
}

error() {
  echo -e "\e[1;31m[ERROR] $1\e[0m"
}

check_prerequisites() {
  info "Verificando prerequisitos..."
  yum install -y git
  if ! command -v sudo &> /dev/null; then
    error "sudo no está instalado. Se requieren permisos de administrador."
    exit 1
  fi
  success "Prerequisitos verificados."
}

update_packages() {
  info "Actualizando paquetes del sistema..."
  sudo yum update -y
  if [ $? -ne 0 ]; then
    error "Error al actualizar los paquetes."
    exit 1
  fi
  success "Paquetes actualizados."
}

install_nodejs_npm() {
  info "Instalando Node.js y npm (versión $NODE_VERSION)..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
  export NVM_DIR="$([ -s "$HOME/.nvm/nvm.sh" ] && echo "$HOME/.nvm" || printf "nvm no found")"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash completion

  nvm install "$NODE_VERSION"
  nvm use "$NODE_VERSION"
  nvm alias default "$NODE_VERSION"

  if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
    error "Error al instalar Node.js o npm. Verifica los logs de instalación de nvm."
    exit 1
  fi
  success "Node.js (v$(node -v)) y npm (v$(npm -v)) instalados."
}

create_app_directory() {
  info "Creando directorio para la aplicación en /var/www/$APP_NAME..."
  sudo mkdir -p /var/www/$APP_NAME
  sudo chown -R $USER:$USER /var/www/$APP_NAME
  success "Directorio /var/www/$APP_NAME creado."
}

transfer_example_app() {
  info "Transfiriendo un ejemplo básico de React..."
  cd /var/www/$APP_NAME
  # Este comando asume que tienes un repositorio Git con un ejemplo de React
  # Puedes reemplazar la URL con la de tu propio repositorio
  git clone https://github.com/PowerBiDevCamp/Power-BI-React-SPA-Starter .
  if [ $? -ne 0 ]; then
    error "Error al clonar el ejemplo de React. Asegúrate de tener Git instalado y la URL sea correcta."
    exit 1
  fi
  success "Ejemplo de React transferido."
}

install_dependencies() {
  info "Instalando dependencias de la aplicación..."
  cd /var/www/$APP_NAME
  nvm use "$NODE_VERSION"
  npm install
  if [ $? -ne 0 ]; then
    error "Error al instalar las dependencias de la aplicación."
    exit 1
  fi
  success "Dependencias instaladas."
}

build_app() {
  info "Construyendo la aplicación React para producción..."
  cd /var/www/$APP_NAME
  npm run build
  if [ $? -ne 0 ]; then
    error "Error al construir la aplicación React."
    exit 1
  fi
  success "Aplicación React construida en el directorio 'build'."
}

install_nginx() {
  info "Instalando Nginx..."
  sudo yum install -y nginx
  if [ $? -ne 0 ]; then
    error "Error al instalar Nginx."
    exit 1
  fi
  success "Nginx instalado."
}

configure_nginx() {
  info "Configurando Nginx para servir la aplicación React..."
  sudo rm /etc/nginx/conf.d/default.conf
  sudo tee /etc/nginx/conf.d/$APP_NAME.conf > /dev/null <<EOF
server {
    listen $PORT;
    server_name _; # Puedes reemplazar _ con tu dominio si lo tienes

    root /var/www/$APP_NAME/build;
    index index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Configuración de compresión gzip para archivos estáticos
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/rss+xml application/atom+xml image/svg+xml;
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


main() {
  check_prerequisites
  update_packages
  install_nodejs_npm
  create_app_directory
  transfer_example_app
  install_dependencies
  build_app
  install_nginx
  configure_nginx
  start_nginx

  echo -e "\n\e[1;32m¡Aplicación React desplegada exitosamente en http://<Tu_IP_EC2>:$PORT!\e[0m"
  echo -e "\e[1;33mRecuerda configurar un nombre de dominio y HTTPS para un entorno de producción real.\e[0m"
}

main "$@"