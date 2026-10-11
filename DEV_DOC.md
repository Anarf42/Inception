# Inception Developer Documentation

## Introduction

This document describes how the Inception infrastructure is configured, built and maintained.

The project is composed of three Docker services:

```text
NGINX
WordPress + PHP-FPM
MariaDB
```

Each service:

- Has its own Dockerfile.
- Is built from Debian Bookworm.
- Runs its main process in foreground mode.
- Is connected to the `inception` Docker network.

Docker Compose is responsible for integrating the services, volumes, network, environment variables and secrets.

---

# Initial machine setup

The development machine requires several basic tools.

Install Git:

```bash
sudo apt-get install git
```

Install Make:

```bash
sudo apt-get install make
```

Optional development utilities:

```bash
sudo apt-get install vim
sudo apt-get install tree
```

---

# Installing Docker

Update the package list:

```bash
sudo apt update
```

Install the required packages:

```bash
sudo apt install ca-certificates curl
```

Create the directory for Docker's repository key:

```bash
sudo install -m 0755 -d /etc/apt/keyrings
```

Download the official Docker key:

```bash
sudo curl -fsSL https://download.docker.com/linux/debian/gpg \
    -o /etc/apt/keyrings/docker.asc
```

Set its permissions:

```bash
sudo chmod 644 /etc/apt/keyrings/docker.asc
```

Add the Docker repository:

```bash
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
```

Update the package list:

```bash
sudo apt update
```

Install Docker and Docker Compose:

```bash
sudo apt install docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin
```

Check the installation:

```bash
docker --version
docker compose version
sudo docker run hello-world
```

To execute Docker commands without `sudo`:

```bash
sudo usermod -aG docker $USER
```

Restart the machine afterwards.

---

# Project structure

The project uses the following general structure:

```text
inception/
├── Makefile
├── secrets/
│   └── .gitkeep
└── srcs/
    ├── .env
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/
        │   ├── conf/
        │   │   └── mariadb.cnf
        │   ├── tools/
        │   │   └── init.sh
        │   └── Dockerfile
        │
        ├── nginx/
        │   ├── conf/
        │   │   └── nginx.conf
        │   └── Dockerfile
        │
        └── wordpress/
            ├── conf/
            ├── tools/
            │   └── init.sh
            └── Dockerfile
```

Each service is built independently and later integrated through Docker Compose.

---

# NGINX configuration

The NGINX image is built from Debian Bookworm.

The Dockerfile installs:

```text
nginx
openssl
```

OpenSSL is used to generate the project's self-signed TLS certificate during the image build.

NGINX listens on:

```text
443
```

with SSL enabled.

The configuration allows:

```text
TLSv1.2
TLSv1.3
```

NGINX is started in foreground mode:

```bash
nginx -g "daemon off;"
```

This is important because Docker keeps a container running while its main process is running.

WordPress PHP requests are forwarded with:

```nginx
fastcgi_pass wordpress:9000;
```

Docker's internal DNS resolves `wordpress` to the WordPress container.

NGINX is the only service that publishes a port to the host.

---

# MariaDB configuration

MariaDB is also built from Debian Bookworm.

Its configuration uses:

```text
port = 3306
bind-address = 0.0.0.0
datadir = /var/lib/mysql
```

Using:

```text
bind-address = 0.0.0.0
```

is necessary so MariaDB can accept connections from other containers instead of listening only on `127.0.0.1`.

The initialization script:

1. Reads the database secrets.
2. Verifies the required environment variables.
3. Creates the required directories.
4. Initializes MariaDB if no previous database exists.
5. Uses MariaDB bootstrap mode to configure the database.
6. Creates the WordPress database.
7. Creates the WordPress database user.
8. Grants the required privileges.
9. Starts the final MariaDB server.

Bootstrap mode allows the SQL initialization to be executed without starting a temporary MariaDB server first.

The initialization uses:

```sql
FLUSH PRIVILEGES;
```

before privilege-related operations.

The database is initialized without the default test database and anonymous users.

MariaDB is then started as the main container process using `mariadbd`.

---

# WordPress configuration

The WordPress image contains:

- PHP.
- PHP-FPM.
- PHP CLI.
- PHP MySQL support.
- MariaDB client tools.
- curl.
- WP-CLI.

WP-CLI is installed inside the image and is used to configure WordPress without requiring manual installation through the browser.

The initialization script performs the following sequence:

```text
Read secrets
      |
Check variables
      |
Create /var/www/html
      |
Wait for MariaDB
      |
Download WordPress
      |
Create wp-config.php
      |
Install WordPress
      |
Create second user
      |
Set permissions
      |
Start PHP-FPM
```

MariaDB availability is verified with a real SQL connection. This confirms that:

- MariaDB is running.
- The `wpuser` account exists.
- Its password is valid.
- The `wordpress` database exists.
- SQL queries can be executed.

WordPress files are assigned to:

```text
www-data:www-data
```

so PHP-FPM can access them.

PHP-FPM is finally started in foreground mode.

---

# Environment configuration

Non-sensitive values are stored in:

```text
srcs/.env
```

The configuration includes values such as:

```env
MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser
MYSQL_HOST=mariadb

DOMAIN_NAME=anruiz-d.42.fr

WP_TITLE=Inception

WP_ADMIN_USER=siteowner
WP_ADMIN_EMAIL=siteowner@example.com

WP_USER=usuario
WP_USER_EMAIL=usuario@example.com

LOGIN=anruiz-d
```

`LOGIN` is used to avoid hardcoding the login repeatedly in paths and commands.

---

# Secrets configuration

Create:

```text
secrets/db_password.txt
secrets/db_root_password.txt
secrets/wp_admin_password.txt
secrets/wp_user_password.txt
```

Each file contains only the corresponding password.

Restrict their permissions:

```bash
chmod 600 secrets/*.txt
```

They must not be committed.

The `.gitignore` contains:

```gitignore
secrets/*.txt
inception
*.swp
*.swo
.DS_Store
```

The repository can keep:

```text
secrets/.gitkeep
```

because Git does not track empty directories.

---

# Docker network

The services use a custom bridge network called:

```text
inception
```

Docker Compose defines it using the bridge driver.

All three services are connected to it.

The network provides internal DNS resolution, which allows services to communicate by name.

For example:

```text
WordPress -> mariadb:3306
NGINX     -> wordpress:9000
```

No container IP address needs to be hardcoded.

Only NGINX publishes a host port.

The network can be inspected with:

```bash
docker network inspect inception
```

---

# Persistent storage

Two persistent data locations are used:

```text
/home/anruiz-d/data/mariadb
/home/anruiz-d/data/wordpress
```

The Makefile creates them automatically if they do not already exist.

They correspond to:

```text
MariaDB:
Host:
    /home/anruiz-d/data/mariadb

Container:
    /var/lib/mysql
```

and:

```text
WordPress:
Host:
    /home/anruiz-d/data/wordpress

Container:
    /var/www/html
```

Because these files are stored outside the containers, deleting and recreating containers does not remove the database or WordPress installation.

---

# Docker Compose

The Compose file is located at:

```text
srcs/docker-compose.yml
```

Before starting the infrastructure, its syntax and resolved configuration can be checked with:

```bash
docker compose \
    --env-file srcs/.env \
    -f srcs/docker-compose.yml \
    config
```

Docker Compose manages:

- The three services.
- Docker image builds.
- The `inception` network.
- Persistent volumes.
- Environment variables.
- Secrets.
- Container restart configuration.
- Port `443` for NGINX.

Each container receives only the secrets required by that service.

---

# Building and starting manually with Docker Compose

Build the images:

```bash
docker compose \
    --env-file srcs/.env \
    -f srcs/docker-compose.yml \
    build
```

Start the services:

```bash
docker compose \
    --env-file srcs/.env \
    -f srcs/docker-compose.yml \
    up
```

Or build and start them together:

```bash
docker compose \
    --env-file srcs/.env \
    -f srcs/docker-compose.yml \
    up --build
```

To run them in the background:

```bash
docker compose \
    --env-file srcs/.env \
    -f srcs/docker-compose.yml \
    up -d --build
```

---

# Using the Makefile

The Makefile simplifies the Docker Compose commands.

## Start the project

```bash
make
```

or:

```bash
make up
```

This:

1. Creates the persistent directories.
2. Builds the Docker images.
3. Starts the Docker Compose stack.

---

## Stop the project

```bash
make down
```

This removes the containers and Compose network while keeping images and persistent data.

---

## Clean containers

```bash
make clean
```

This stops the stack and removes orphan containers while preserving the persistent data.

---

## Complete cleanup

```bash
make fclean
```

This performs the complete project cleanup, including the Docker resources and persistent project data configured by the Makefile.

---

## Rebuild everything

```bash
make re
```

Equivalent to performing a complete cleanup followed by a new build and start.

---

# Useful Docker commands

## List running containers

```bash
docker ps
```

## List all containers

```bash
docker ps -a
```

## List images

```bash
docker images
```

## Inspect the Docker network

```bash
docker network inspect inception
```

## Execute a command inside a container

```bash
docker exec <container> <command>
```

Example:

```bash
docker exec wordpress wp --info --allow-root
```

---

# Service verification

## Validate NGINX configuration

```bash
docker run --rm \
    --network inception \
    nginx \
    nginx -t
```

---

## Test HTTPS

```bash
curl -k https://localhost
```

or:

```bash
curl -k https://anruiz-d.42.fr
```

---

## Check MariaDB

```bash
docker exec mariadb mariadb-admin ping
```

Check the WordPress tables:

```bash
docker exec mariadb mariadb \
    -u wpuser \
    -p"$(cat secrets/db_password.txt)" \
    wordpress \
    -e "SHOW TABLES;"
```

---

## Check WordPress users

```bash
docker exec wordpress wp user list \
    --path=/var/www/html \
    --allow-root
```

---

# Data persistence verification

Persistence can be tested by:

```bash
make up
```

Verify WordPress and the database, then stop the stack:

```bash
make down
```

Start it again:

```bash
make up
```

The WordPress installation, users and database tables should still exist.

This confirms that the data stored in:

```text
/home/anruiz-d/data/mariadb
/home/anruiz-d/data/wordpress
```

is independent from the lifecycle of the containers.

---

# Local domain configuration

The development machine must resolve:

```text
anruiz-d.42.fr
```

to the virtual machine.

Add to `/etc/hosts`:

```text
127.0.0.1 anruiz-d.42.fr
```

The infrastructure can then be accessed at:

```text
https://anruiz-d.42.fr
```
