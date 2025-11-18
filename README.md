# LAMP + MariaDB + phpMyAdmin en un solo contenedor (para Coolify v4)

Basado en `php:8.2-apache` con:

- Apache + PHP 8.2
- MariaDB Server
- phpMyAdmin en `/phpmyadmin`
- Script de arranque que inicializa la base de datos según variables de entorno.

## Variables de entorno

- `MARIADB_ROOT_PASSWORD`
- `MARIADB_DATABASE`
- `MARIADB_USER`
- `MARIADB_PASSWORD`

## Persistencia

En Coolify, montar un **Directory Mount**:

- Source: `/data/coolify/apps/mysql-admchile-db` (o similar)
- Destination: `/bitnami/mariadb`

## Uso en Coolify

- Build pack: Dockerfile
- Internal port: 80
