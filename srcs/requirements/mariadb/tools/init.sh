#!/bin/sh

set -e

#leemos los secrets
DB_PASSWORD=$(cat /run/secrets/db_password)
DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)

#comprobamos las variables .env
if [ -z  "$MYSQL_DATABASE" ] || [ -z "$MYSQL_USER" ]; then
	echo "Error: MYSQL_DATABASE o MYSQL_USER no definidos"
	exit 1
fi

#creamos la carpeta y otorgamos los permisos
mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld /var/lib/mysql

#inicializamos solo si mariaddb no lo esta
if [ ! -d "/var/lib/mysql/mysql" ]; then

	echo "Inicializando MariaDB..."

	mariadb-install-db --user=mysql --datadir=/var/lib/mysql --skip-test-db
	mariadbd --user=mysql --datadir=/var/lib/mysql --bootstrap <<EOF
FLUSH PRIVILEGES;

ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';

CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;

CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';

GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';

FLUSH PRIVILEGES;
EOF
fi
exec mariadbd --user=mysql --datadir=/var/lib/mysql

