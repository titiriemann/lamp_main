#!/usr/bin/env bash
set -e

: "${MARIADB_ROOT_PASSWORD:?MARIADB_ROOT_PASSWORD is required}"
: "${MARIADB_DATABASE:?MARIADB_DATABASE is required}"
: "${MARIADB_USER:?MARIADB_USER is required}"
: "${MARIADB_PASSWORD:?MARIADB_PASSWORD is required}"

DATADIR="${MARIADB_DATA_DIR:-/bitnami/mariadb}"
SOCKET="/run/mysqld/mysqld.sock"

echo "[INFO] Usando datadir: $DATADIR"

mkdir -p "$DATADIR" /run/mysqld
chown -R mysql:mysql "$DATADIR" /run/mysqld

########################################
# 1) Inicialización primera vez
########################################
if [ ! -d "$DATADIR/mysql" ]; then
  echo "[INFO] Inicializando MariaDB en $DATADIR"
  mariadb-install-db --user=mysql --datadir="$DATADIR" > /dev/null

  echo "[INFO] Levantando MariaDB en modo init..."
  mysqld_safe --datadir="$DATADIR" --socket="$SOCKET" --bind-address=127.0.0.1 --port=3306 &
  INIT_PID=$!

  for i in {60..0}; do
    if mysqladmin --socket="$SOCKET" ping &>/dev/null; then
      echo "[INFO] MariaDB está arriba (init)."
      break
    fi
    echo "[INFO] Esperando a MariaDB (init)... ($i)"
    sleep 1
  done

  echo "[INFO] Configurando contraseña de root (primera vez, sin password)..."
  mysql --socket="$SOCKET" <<EOSQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOSQL

  echo "[INFO] Creando BD y usuario ${MARIADB_USER} (init)..."
  mysql --socket="$SOCKET" -uroot -p"${MARIADB_ROOT_PASSWORD}" <<EOSQL
CREATE DATABASE IF NOT EXISTS \`${MARIADB_DATABASE}\`
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS '${MARIADB_USER}'@'localhost' IDENTIFIED BY '${MARIADB_PASSWORD}';
CREATE USER IF NOT EXISTS '${MARIADB_USER}'@'%'         IDENTIFIED BY '${MARIADB_PASSWORD}';

GRANT ALL PRIVILEGES ON \`${MARIADB_DATABASE}\`.* TO '${MARIADB_USER}'@'localhost';
GRANT ALL PRIVILEGES ON \`${MARIADB_DATABASE}\`.* TO '${MARIADB_USER}'@'%';
FLUSH PRIVILEGES;
EOSQL

  echo "[INFO] Apagando MariaDB de inicialización..."
  mysqladmin --socket="$SOCKET" -uroot -p"${MARIADB_ROOT_PASSWORD}" shutdown
  wait "$INIT_PID"
fi

########################################
# 2) Arranque normal
########################################
echo "[INFO] Levantando MariaDB (normal)..."
mysqld_safe --datadir="$DATADIR" --socket="$SOCKET" --bind-address=0.0.0.0 --port=3306 &
MYSQL_PID=$!

for i in {60..0}; do
  if mysqladmin --socket="$SOCKET" -uroot -p"${MARIADB_ROOT_PASSWORD}" ping &>/dev/null; then
    echo "[INFO] MariaDB está arriba (normal)."
    break
  fi
  echo "[INFO] Esperando a MariaDB (normal)... ($i)"
  sleep 1
done

########################################
# 3) Ajustar siempre BD y usuario de aplicación
########################################
echo "[INFO] Ajustando BD ${MARIADB_DATABASE} y usuario ${MARIADB_USER}..."
mysql --socket="$SOCKET" -uroot -p"${MARIADB_ROOT_PASSWORD}" <<EOSQL
CREATE DATABASE IF NOT EXISTS \`${MARIADB_DATABASE}\`
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS '${MARIADB_USER}'@'localhost' IDENTIFIED BY '${MARIADB_PASSWORD}';
CREATE USER IF NOT EXISTS '${MARIADB_USER}'@'%'         IDENTIFIED BY '${MARIADB_PASSWORD}';

ALTER USER '${MARIADB_USER}'@'localhost' IDENTIFIED BY '${MARIADB_PASSWORD}';
ALTER USER '${MARIADB_USER}'@'%'         IDENTIFIED BY '${MARIADB_PASSWORD}';

GRANT ALL PRIVILEGES ON \`${MARIADB_DATABASE}\`.* TO '${MARIADB_USER}'@'localhost';
GRANT ALL PRIVILEGES ON \`${MARIADB_DATABASE}\`.* TO '${MARIADB_USER}'@'%';
FLUSH PRIVILEGES;
EOSQL

########################################
# 4) Levantar Apache
########################################
echo "[INFO] Levantando Apache..."
apache2-foreground &
APACHE_PID=$!

trap "echo '[INFO] Deteniendo servicios...'; kill $MYSQL_PID $APACHE_PID; wait" SIGTERM SIGINT

wait
