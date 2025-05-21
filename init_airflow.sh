#!/bin/bash
# Configuramos nuestro entorno virtual de Python(No es obligatorio)
sudo yum -y install virtualenv
virtualenv env
source ./env/bin/activate

# Configuramos la variable virtual con la carpeta donde instalamos Airflow
export AIRFLOW_HOME=/opt/posts/airflow
sudo mkdir -p $AIRFLOW_HOME
sudo chown -R $(whoami) $AIRFLOW_HOME
# Configuramos varias variables virtuales con la versión de Airflow que queremos y las versiones de Python y la URL de los constraits que se autoconfiguran
AIRFLOW_VERSION=2.6.3
PYTHON_VERSION="$(python3 --version | cut -d " " -f 2 | cut -d "." -f 1-2)"
CONSTRAINT_URL="https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${PYTHON_VERSION}.txt"

# Finalmente instalamos Airflow con la herramienta PIP
pip install "apache-airflow==${AIRFLOW_VERSION}" --constraint "${CONSTRAINT_URL}"

cd $AIRFLOW_HOME
# Inicializamos la base de datos de Airflow
airflow db init
# Creamos un usuario administrador para la interfaz web de Airflow
airflow users create \
    --username admin \
    --password admin \
    --firstname Admin \
    --lastname User \
    --role Admin \
    --email

# Iniciamos el servidor web de Airflow
airflow webserver --port 8080 --daemon
# Iniciamos el scheduler de Airflow
airflow scheduler --daemon
# Iniciamos el servidor de Airflow
airflow standalone
# Iniciamos el servidor de Airflow