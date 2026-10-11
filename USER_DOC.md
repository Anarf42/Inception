# Inception User Documentation

## Introduction

This document explains how to use the Inception infrastructure once it has been configured.

The project provides a WordPress website running through three Docker services:

```text
NGINX
WordPress + PHP-FPM
MariaDB
```

The services run inside separate containers and communicate through the Docker network called `inception`.

---

## Services provided by the stack

### NGINX

NGINX is the public entry point of the infrastructure.

It:

- Accepts HTTPS connections.
- Exposes port `443`.
- Uses TLS 1.2 and TLS 1.3.
- Serves the WordPress website.
- Sends PHP requests to WordPress through FastCGI.

NGINX communicates with WordPress using:

```text
wordpress:9000
```

Only NGINX publishes a port outside the Docker network.

---

### WordPress

The WordPress container contains:

- WordPress.
- PHP.
- PHP-FPM.
- WP-CLI.
- MariaDB client tools.

PHP-FPM listens internally on:

```text
9000
```

WordPress is automatically configured when the container is initialized.

The initialization process:

1. Reads the required secrets.
2. Waits until MariaDB is available.
3. Downloads WordPress if necessary.
4. Creates `wp-config.php`.
5. Installs WordPress.
6. Creates the required WordPress users.
7. Gives the files the appropriate permissions.
8. Starts PHP-FPM in foreground mode.

---

### MariaDB

MariaDB stores all WordPress database information.

It runs internally on:

```text
3306
```

The WordPress container connects to it using the Docker service name:

```text
mariadb
```

MariaDB data is persisted outside the container.

---

# Starting the project

From the root of the repository, run:

```bash
make
```

Alternatively:

```bash
make up
```

The command:

- Creates the required data directories.
- Builds the Docker images.
- Creates the Docker network.
- Creates the containers.
- Mounts the required secrets.
- Mounts the persistent storage.
- Starts all services.

Check the running containers with:

```bash
docker ps
```

Three containers should be running:

```text
nginx
wordpress
mariadb
```

---

# Accessing the website

The project uses the local domain:

```text
anruiz-d.42.fr
```

It must resolve to the virtual machine.

The `/etc/hosts` file should contain:

```text
127.0.0.1 anruiz-d.42.fr
```

The website can then be accessed at:

```text
https://anruiz-d.42.fr
```

The project uses a self-signed TLS certificate, so the browser may display a security warning.

---

# Accessing the WordPress administration panel

The WordPress administration panel is available at:

```text
https://anruiz-d.42.fr/wp-admin
```

Log in using the WordPress administrator username configured in:

```text
srcs/.env
```

and the administrator password stored in:

```text
secrets/wp_admin_password.txt
```

The password must not be stored directly inside the `.env` file.

---

# Managing credentials

The project separates normal configuration from sensitive information.

## Environment variables

Non-sensitive information is stored in:

```text
srcs/.env
```

Examples include:

```env
MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser
MYSQL_HOST=mariadb

DOMAIN_NAME=anruiz-d.42.fr

WP_ADMIN_USER=siteowner
WP_ADMIN_EMAIL=siteowner@example.com

WP_USER=usuario
WP_USER_EMAIL=usuario@example.com
```

---

## Secrets

Passwords are stored inside:

```text
secrets/
```

The required secret files are:

```text
db_password.txt
db_root_password.txt
wp_admin_password.txt
wp_user_password.txt
```

The permissions of these files should be restricted:

```bash
chmod 600 secrets/*.txt
```

They are ignored by Git and must never be committed to the repository.

Each container only receives the secrets it requires.

---

# Stopping the project

To stop the infrastructure while preserving the data:

```bash
make down
```

This removes the containers and the Docker Compose network but keeps the persistent website and database data.

The project can later be started again with:

```bash
make up
```

---

# Cleaning the project

Several Makefile rules are available.

### Normal cleanup

```bash
make clean
```

This stops the stack and removes orphan containers while preserving persistent data.

### Complete cleanup

```bash
make fclean
```

This performs a complete cleanup of the infrastructure.

Use this command carefully because the current project configuration also removes persistent project data.

### Rebuild everything

```bash
make re
```

This performs:

```text
fclean -> rebuild -> start
```

---

# Checking that the services are working

## Check running containers

```bash
docker ps
```

NGINX, WordPress and MariaDB should all appear as running.

---

## Test the website

From the virtual machine:

```bash
curl -k https://localhost
```

or:

```bash
curl -k https://anruiz-d.42.fr
```

A successful request should return the WordPress HTML.

The `-k` option is required because the project uses a self-signed certificate.

---

## Check MariaDB

MariaDB can be tested with:

```bash
docker exec mariadb mariadb-admin ping
```

The WordPress database tables can also be checked with:

```bash
docker exec mariadb mariadb \
    -u wpuser \
    -p"$(cat secrets/db_password.txt)" \
    wordpress \
    -e "SHOW TABLES;"
```

WordPress tables such as `wp_users`, `wp_posts` and others should be present after installation.

---

## Check WordPress users

WordPress users can be listed using WP-CLI:

```bash
docker exec wordpress wp user list \
    --path=/var/www/html \
    --allow-root
```

The administrator and the additional WordPress user should appear.

---

## Check the Docker network

The network can be inspected with:

```bash
docker network inspect inception
```

The three services should be connected to the network.

---

# Checking data persistence

To verify persistence:

1. Start the project:

```bash
make up
```

2. Verify that WordPress works and that the database contains its tables.

3. Stop the containers:

```bash
make down
```

4. Start them again:

```bash
make up
```

5. Access the website again.

The WordPress installation, users and database tables should still be present because their data is stored outside the containers.

Persistent data is stored under:

```text
/home/anruiz-d/data/mariadb
/home/anruiz-d/data/wordpress
```
