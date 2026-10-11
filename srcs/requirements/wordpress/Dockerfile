FROM	debian:bookworm

RUN	apt-get update && apt-get install -y \
	php-fpm \
	php-cli \
	php-mysql \
	php-curl \
	php-mbstring \
	php-xml \
	php-zip \
	php-gd \
	mariadb-client \
	curl \
	ca-certificates && rm -rf /var/lib/apt/lists/*

RUN	curl -o /usr/local/bin/wp \
	https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
	chmod +x /usr/local/bin/wp

COPY	conf/www.conf	/etc/php/8.2/fpm/pool.d/www.conf

COPY	tools/init.sh	/usr/local/bin/init.sh

RUN	chmod +x /usr/local/bin/init.sh && \
	mkdir -p /run/php

ENTRYPOINT	["/usr/local/bin/init.sh"]
