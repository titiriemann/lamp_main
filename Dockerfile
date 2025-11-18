FROM php:8.2-apache

# Instalar MariaDB, cliente, wget, unzip y extensiones PHP
RUN apt-get update \
 && apt-get install -y mariadb-server mariadb-client wget unzip \
 && docker-php-ext-install mysqli pdo pdo_mysql \
 && rm -rf /var/lib/apt/lists/*

# Instalar phpMyAdmin en /var/www/html/phpmyadmin
RUN mkdir -p /var/www/html/phpmyadmin \
 && cd /tmp \
 && wget https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.zip \
 && unzip phpMyAdmin-5.2.1-all-languages.zip \
 && mv phpMyAdmin-5.2.1-all-languages/* /var/www/html/phpmyadmin \
 && rm -rf phpMyAdmin-5.2.1-all-languages*

# Configuración mínima de phpMyAdmin
COPY docker/config.inc.php /var/www/html/phpmyadmin/config.inc.php

# Directorio de datos de MariaDB
RUN mkdir -p /bitnami/mariadb /run/mysqld \
 && chown -R mysql:mysql /bitnami/mariadb /run/mysqld

# Copiar aplicación PHP
COPY app/ /var/www/html/

# Script de arranque
COPY docker/start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

ENV MARIADB_DATA_DIR=/bitnami/mariadb

EXPOSE 80

# Healthcheck: revisa que Apache responda en /health.php
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD wget -qO- http://localhost/health.php > /dev/null 2>&1 || exit 1

ENTRYPOINT ["/usr/local/bin/start.sh"]
