FROM	debian:bookworm

RUN	apt-get update && \
	apt-get install -y nginx -y openssl && \
	rm -rf /var/lib/apt/lists/*

RUN	mkdir -p /etc/nginx/ssl && \
	openssl req -x509 -nodes \
	-out /etc/nginx/ssl/nginx.crt \
	-keyout /etc/nginx/ssl/nginx.key \
	-subj "/C=ES/ST=Madrid/L=Madrid/O=42/OU=42Madrid/CN=anruiz-d.42.fr"

COPY	conf/nginx.conf /etc/nginx/nginx.conf

CMD	["nginx", "-g", "daemon off;"]
