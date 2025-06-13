#!/bin/bash -ex
# Script para instalar WordPress + phpMyAdmin en Ubuntu Server

# --- PERSONALIZA TU CONFIGURACIÓN AQUÍ ---
DB_NAME="dbwordpress"
DB_USER="admin"
DB_PASS="Tecsup00--"
# --- FIN DE LA ZONA DE PERSONALIZACIÓN ---

# Actualizar sistema
sudo apt-get update -y
sudo apt-get upgrade -y

# Instalar Apache, MySQL Server y PHP con módulos necesarios
sudo apt-get install -y apache2 mysql-server php php-mysql php-gd php-xml php-mbstring wget unzip curl

# Instalar phpMyAdmin (no interactivo)
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean true"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/app-password-confirm password ${DB_PASS}"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/admin-pass password ${DB_PASS}"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/app-pass password ${DB_PASS}"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2"
sudo apt-get install -y phpmyadmin

# Habilitar el módulo PHP para Apache y reiniciar
sudo phpenmod mbstring
sudo systemctl restart apache2

# --- Configuración de la Base de Datos ---
# Configurar MySQL: crear la base de datos y el usuario
sudo mysql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${DB_PASS}';
CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

# --- Instalación y Configuración de WordPress ---
cd /var/www/html
sudo rm -rf index.html
sudo wget https://wordpress.org/latest.tar.gz
sudo tar -xzf latest.tar.gz
sudo mv wordpress/* .
sudo rmdir wordpress
sudo rm latest.tar.gz

# Crear y configurar wp-config.php
sudo cp wp-config-sample.php wp-config.php
sudo sed -i "s/database_name_here/$DB_NAME/" wp-config.php
sudo sed -i "s/username_here/$DB_USER/" wp-config.php
sudo sed -i "s/password_here/$DB_PASS/" wp-config.php

# Insertar claves de seguridad únicas de la API de WordPress.org
SALT=$(curl -L https://api.wordpress.org/secret-key/1.1/salt/)
sudo sed -i "/AUTH_KEY/d" wp-config.php
sudo sed -i "/SECURE_AUTH_KEY/d" wp-config.php
sudo sed -i "/LOGGED_IN_KEY/d" wp-config.php
sudo sed -i "/NONCE_KEY/d" wp-config.php
sudo sed -i "/AUTH_SALT/d" wp-config.php
sudo sed -i "/SECURE_AUTH_SALT/d" wp-config.php
sudo sed -i "/LOGGED_IN_SALT/d" wp-config.php
sudo sed -i "/NONCE_SALT/d" wp-config.php
echo "$SALT" | sudo tee -a wp-config.php

# --- Configuración de phpMyAdmin ---
# Hacer que phpMyAdmin sea accesible desde cualquier IP
sudo sed -i "s/Require local/Require all granted/" /etc/apache2/conf-available/phpmyadmin.conf
sudo ln -s /etc/apache2/conf-available/phpmyadmin.conf /etc/apache2/conf-enabled/phpmyadmin.conf || true
sudo systemctl reload apache2

# --- Permisos Finales ---
sudo chown -R www-data:www-data /var/www/html/
sudo find /var/www/html/ -type d -exec chmod 755 {} \;
sudo find /var/www/html/ -type f -exec chmod 644 {} \;

echo "Instalación completa. Accede a WordPress en http://<tu-ip-publica> y a phpMyAdmin en http://<tu-ip-publica>/phpmyadmin"
