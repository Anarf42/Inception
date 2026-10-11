#!/bin/sh

set -e

#Leemos los secrets
DB_PASSWORD=$(cat /run/secrets/db_password)
WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)
WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password)

#Comprobamos que los secrets no es esten vacios
if [ -z "$DB_PASSWORD" ] || \
   [ -z "$WP_ADMIN_PASSWORD" ] || \
   [ -z "$WP_USER_PASSWORD" ]; then
	echo "Error: alguno de los secrets está vacío"
	exit 1
fi

#creamosel directorio de WordPress
mkdir -p /var/www/html

#Esperamos a que MariaDB este disponible
until mariadb \
	-h "$MYSQL_HOST" \
	-u "$MYSQL_USER" \
	-p"$DB_PASSWORD" \
	"$MYSQL_DATABASE" \
	-e "SELECT 1;" > /dev/null 2>&1
do
	echo "Esperando a MariaDB..."
	sleep 2
done

echo "MariaDB disponible"

#Descargamos WordPress si no existe
if [ ! -f /var/www/html/wp-settings.php ]; then
	echo "Descargando WordPress..."

	wp core download \
		--path=/var/www/html \
		--allow-root
fi

#Creamos wp-config.php si todavía no existe
if [ ! -f /var/www/html/wp-config.php ]; then
	echo "Creando wp-config.php..."

	wp config create \
		--path=/var/www/html \
		--dbname="$MYSQL_DATABASE" \
		--dbuser="$MYSQL_USER" \
		--dbpass="$DB_PASSWORD" \
		--dbhost="${MYSQL_HOST}:3306" \
		--allow-root
fi

wp config set WP_HOME \
	"isset(\$_SERVER['HTTP_HOST']) ? 'https://' . \$_SERVER['HTTP_HOST'] : 'https://${DOMAIN_NAME}'" \
	--raw \
	--path=/var/www/html \
	--allow-root

wp config set WP_SITEURL \
	"isset(\$_SERVER['HTTP_HOST']) ? 'https://' . \$_SERVER['HTTP_HOST'] : 'https://${DOMAIN_NAME}'" \
	--raw \
	--path=/var/www/html \
	--allow-root

#Instalamos WordPress si no está instalado
if ! wp core is-installed \
	--path=/var/www/html \
	--allow-root > /dev/null 2>&1
then
	echo "Instalando WordPress..."

	wp core install \
		--path=/var/www/html \
		--url="https://${DOMAIN_NAME}" \
		--title="$WP_TITLE" \
		--admin_user="$WP_ADMIN_USER" \
		--admin_password="$WP_ADMIN_PASSWORD" \
		--admin_email="$WP_ADMIN_EMAIL" \
		--skip-email \
		--allow-root
fi

#Creamos el segundo usuario si no existe
if ! wp user get "$WP_USER" \
	--path=/var/www/html \
	--allow-root > /dev/null 2>&1
then
	echo "Creando usuario WordPress..."

	wp user create \
		"$WP_USER" \
		"$WP_USER_EMAIL" \
		--role=author \
		--user_pass="$WP_USER_PASSWORD" \
		--path=/var/www/html \
		--allow-root
fi

#Permisos para PHP-FPM
chown -R www-data:www-data /var/www/html

echo "WordPress preparado correctamente"

exec php-fpm8.2 -F
