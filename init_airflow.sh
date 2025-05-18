#!/bin/bash

# Variables de configuración
AIRFLOW_HOME="/opt/airflow" # Directorio de instalación preferido en sistemas basados en Linux
PYTHON_VERSION="3.8"
AIRFLOW_VERSION="2.8.3"
DB_ENGINE="sqlite"
AIRFLOW_USER="airflow"

# Funciones útiles
info() {
  echo -e "\e[1;34m[INFO] $1\e[0m"
}

success() {
  echo -e "\e[1;32m[OK] $1\e[0m"
}

error() {
  echo -e "\e[1;31m[ERROR] $1\e[0m"
}

install_prerequisites() {
  info "Verificando e instalando prerequisitos..."

  # Actualizar paquetes
  sudo yum update -y

  # Instalar Python 3 y pip
  if ! command -v python3 &> /dev/null; then
    error "Python 3 no está instalado. Intentando instalar..."
    sudo yum install -y python3 python3-devel
    if [ $? -ne 0 ]; then
      error "Error al instalar Python 3. Por favor, instálalo manualmente."
      exit 1
    fi
  fi
  success "Python 3 instalado."

  if ! command -v pip3 &> /dev/null; then
    error "pip3 no está instalado. Intentando instalar..."
    sudo yum install -y python3-pip
    if [ $? -ne 0 ]; then
      error "Error al instalar pip3. Por favor, instálalo manualmente."
      exit 1
    fi
  fi
  success "pip3 instalado."

  # Instalar virtualenv
  if ! command -v virtualenv &> /dev/null; then
    info "virtualenv no encontrado. Intentando instalar..."
    sudo pip3 install virtualenv
    if [ $? -ne 0 ]; then
      error "Error al instalar virtualenv. Por favor, instálalo manualmente."
      exit 1
    fi
  fi
  success "virtualenv instalado."
}

create_airflow_user() {
  info "Creando usuario para Airflow..."
  id -u "$AIRFLOW_USER" &> /dev/null
  if [ $? -ne 0 ]; then
    sudo adduser --disabled-login "$AIRFLOW_USER"
    if [ $? -ne 0 ]; then
      error "Error al crear el usuario '$AIRFLOW_USER'."
      exit 1
    fi
    success "Usuario '$AIRFLOW_USER' creado."
  else
    info "El usuario '$AIRFLOW_USER' ya existe."
  fi
}

create_airflow_home() {
  info "Creando directorio AIRFLOW_HOME en '$AIRFLOW_HOME'..."
  sudo mkdir -p "$AIRFLOW_HOME"
  sudo chown "$AIRFLOW_USER":"$AIRFLOW_USER" "$AIRFLOW_HOME"
  success "Directorio AIRFLOW_HOME creado."
}

check_airflow_installed() {
  info "Verificando si Airflow ya está instalado..."
  if [ -d "$AIRFLOW_HOME" ] && [ -f "$AIRFLOW_HOME/airflow.cfg" ]; then
    info "Parece que Airflow ya está instalado en '$AIRFLOW_HOME'."
    exit 0
  fi
  success "Airflow no encontrado. Procediendo con la instalación."
}

setup_virtual_environment() {
  info "Configurando entorno virtual..."
  sudo su - "$AIRFLOW_USER" -c "
    cd $AIRFLOW_HOME
    virtualenv -p \"python${PYTHON_VERSION}\" venv
    source venv/bin/activate
    success \"Entorno virtual activado.\"
  "
}

install_airflow() {
  info "Instalando Apache Airflow versión '$AIRFLOW_VERSION'..."
  sudo su - "$AIRFLOW_USER" -c "
    cd $AIRFLOW_HOME
    source venv/bin/activate
    pip install apache-airflow==\"${AIRFLOW_VERSION}\" --constraint \"https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${PYTHON_VERSION}.txt\"
    if [ \$? -ne 0 ]; then
      error \"Error al instalar Apache Airflow.\"
      deactivate
      exit 1
    fi
    success \"Apache Airflow instalado.\"
  "
}

configure_airflow() {
  info "Configurando Airflow..."
  sudo su - "$AIRFLOW_USER" -c "
    cd $AIRFLOW_HOME
    source venv/bin/activate
    if [ \"\$DB_ENGINE\" == \"postgresql\" ]; then
      # Ejemplo para PostgreSQL (necesitas instalar el driver: pip install psycopg2-binary)
      sed -i \"s/^sql_alchemy_conn = .*$/sql_alchemy_conn = postgresql+psycopg2:\/\/airflow:airflow@localhost:5432\/airflow/\" airflow.cfg
    elif [ \"\$DB_ENGINE\" == \"mysql\" ]; then
      # Ejemplo para MySQL (necesitas instalar el driver: pip install mysqlclient)
      sed -i \"s/^sql_alchemy_conn = .*$/sql_alchemy_conn = mysql+mysqldb:\/\/airflow:airflow@localhost:3306\/airflow/\" airflow.cfg
    else
      info \"Usando SQLite como backend de la base de datos.\"
    fi

    # Puedes agregar más configuraciones aquí según tus necesidades
    # Por ejemplo, cambiar el puerto del webserver:
    # sed -i "s/^web_server_port = .*$/web_server_port = 8080/" airflow.cfg

    success \"Airflow configurado.\"
  "
}

initialize_database() {
  info "Inicializando la base de datos de Airflow..."
  sudo su - "$AIRFLOW_USER" -c "
    cd $AIRFLOW_HOME
    source venv/bin/activate
    airflow db init
    if [ \$? -ne 0 ]; then
      error \"Error al inicializar la base de datos de Airflow.\"
      exit 1
    fi
    success \"Base de datos de Airflow inicializada.\"
  "
}

create_admin_user() {
  info "Creando usuario administrador de Airflow..."
  sudo su - "$AIRFLOW_USER" -c "
    cd $AIRFLOW_HOME
    source venv/bin/activate
    airflow users create \
      --username admin \
      --firstname Admin \
      --lastname User \
      --role Admin \
      --password admin
    if [ \$? -ne 0 ]; then
      error \"Error al crear el usuario administrador.\"
    else
      success \"Usuario administrador creado (username: admin, password: admin). ¡Recuerda cambiar la contraseña!\"
    fi
  "
}

start_airflow_components() {
  info "Iniciando los componentes de Airflow en segundo plano..."
  sudo su - "$AIRFLOW_USER" -c "
    cd $AIRFLOW_HOME
    source venv/bin/activate
    nohup airflow webserver -D &
    echo \"Webserver iniciado en el puerto 8080 (por defecto).\"
    nohup airflow scheduler -D &
    echo \"Scheduler iniciado.\"
    success \"Componentes de Airflow iniciados.\"
  "
}

# --- Ejecución del script ---

install_prerequisites
create_airflow_user
create_airflow_home
check_airflow_installed
sudo chown -R "$AIRFLOW_USER":"$AIRFLOW_USER" "$AIRFLOW_HOME"

setup_virtual_environment
install_airflow
configure_airflow
initialize_database
create_admin_user
start_airflow_components

info "¡Instalación y configuración de Airflow completada!"
info "Puedes acceder a la interfaz web en http://<tu_ip>:8080 (o el puerto que hayas configurado)."
info "Para ver los logs del webserver: tail -f '$AIRFLOW_HOME/logs/webserver/*.log'"
info "Para ver los logs del scheduler: tail -f '$AIRFLOW_HOME/logs/scheduler/*.log'"

exit 0