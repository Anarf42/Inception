*This project has been created as part of the 42 curriculum by anruiz-d.*

# Inception

## Description

Inception is a system administration project whose goal is to create a small infrastructure composed of several services running inside Docker containers.

Each service runs in its own container and is built from its own Dockerfile using Debian Bookworm as the base image.

The infrastructure contains three main services:

- **NGINX**
  - Acts as the only entry point to the infrastructure.
  - Accepts HTTPS connections on port `443`.
  - Uses TLS 1.2 and TLS 1.3.
  - Uses a self-signed SSL certificate generated during the image build.
  - Forwards PHP requests to the WordPress container through FastCGI.

- **WordPress + PHP-FPM**
  - Hosts the WordPress application.
  - PHP-FPM listens on port `9000` inside the Docker network.
  - WP-CLI is used to automatically configure WordPress.
  - The initialization script downloads WordPress, creates `wp-config.php`, installs the website and creates the required users.

- **MariaDB**
  - Stores the WordPress database.
  - Listens internally on port `3306`.
  - Is initialized automatically using a shell script and MariaDB's bootstrap mode.
  - Database files are stored persistently outside the container.

The containers communicate through a custom Docker bridge network called `inception`.

Only the NGINX container publishes a port to the host. WordPress and MariaDB remain accessible only through the internal Docker network.

The general request flow is:

```text
Browser
   |
 HTTPS :443
   |
 NGINX
   |
 FastCGI :9000
   |
WordPress / PHP-FPM
   |
 MariaDB :3306
```

Docker's internal DNS allows containers to communicate using service names such as:

```text
wordpress:9000
mariadb:3306
```

instead of depending on container IP addresses.

---

## Instructions

### Requirements

The project requires:

- A Linux virtual machine.
- Docker.
- Docker Compose.
- Make.
- Git.

Docker and Docker Compose can be checked with:

```bash
docker --version
docker compose version
```

A basic Docker installation can also be tested with:

```bash
docker run hello-world
```

### Project structure

The project follows this general structure:

```text
inception/
├── Makefile
├── secrets/
│   ├── db_password.txt
│   ├── db_root_password.txt
│   ├── wp_admin_password.txt
│   └── wp_user_password.txt
└── srcs/
    ├── .env
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/
        │   ├── conf/
        │   ├── tools/
        │   └── Dockerfile
        ├── nginx/
        │   ├── conf/
        │   └── Dockerfile
        └── wordpress/
            ├── conf/
            ├── tools/
            └── Dockerfile
```

### Environment variables

Non-sensitive configuration is stored in:

```text
srcs/.env
```

For example:

```env
MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser
MYSQL_HOST=mariadb

LOGIN=anruiz-d
DOMAIN_NAME=anruiz-d.42.fr
WP_TITLE=Inception

WP_ADMIN_USER=siteowner
WP_ADMIN_EMAIL=siteowner@example.com

WP_USER=usuario
WP_USER_EMAIL=usuario@example.com

SSH_USER=ana
SSH_HOST=127.0.0.1
SSH_PORT=4242

SOCKS_PORT=1080

HOST_IP=192.168.56.10
HOST_PORT=443

LOCAL_IP=127.0.0.1
LOCAL_PORT=8443
```

Passwords must not be stored in `.env`.

### Secrets

Passwords are stored in separate files:

```text
secrets/db_password.txt
secrets/db_root_password.txt
secrets/wp_admin_password.txt
secrets/wp_user_password.txt
```

Their permissions should be restricted:

```bash
chmod 600 secrets/*.txt
```

Secret files must not be committed to Git.

The `.gitignore` contains:

```text
secrets/*.txt
srcs/.env
```

A `.gitkeep` file can be kept inside the `secrets` directory so the empty directory exists in the repository.

### Local domain

The local domain must resolve to the virtual machine.

For the current project:

```text
127.0.0.1 anruiz-d.42.fr
```

This entry can be added to:

```text
/etc/hosts
```

### Start the project

From the project root:

```bash
make env
make ssh-setup
make vm-setup
make all
```

or:

```bash
make up
```

The Makefile creates the .env file from the .env.example template, generates the SSH key and copy it, downloads and install docker, nginx, mariadb and wordpress and with make all, it does the rest that means: creates the persistent data directories if they do not already exist, builds the images, starts the Docker Compose stack and it will open the socks tunnel to connect remotely.

The site can then be accessed at:

```text
https://anruiz-d.42.fr
```

Because the project uses a self-signed certificate, the browser may display a certificate warning.

### Stop the project

```bash
make down
```

This stops and removes the Compose containers and network while preserving images and persistent data.

Other available commands are:

```bash
make clean
make fclean
make re
```

- `make clean`: stops the stack and removes orphan containers while preserving persistent data.
- `make fclean`: performs a complete cleanup.
- `make re`: performs a full cleanup and rebuilds the project.

---

# Technical choices

## Virtual Machines vs Docker

A **Virtual Machine** virtualizes an entire computer. Each VM normally includes its own operating system and kernel and runs through a hypervisor.

Docker containers instead share the host kernel and isolate individual applications and their dependencies.

### Virtual Machines

Advantages:

- Strong isolation.
- Can run completely different operating systems.
- Each VM behaves like an independent machine.

Disadvantages:

- Require more disk space and memory.
- Slower to create and start.
- Each VM needs its own operating system.

### Docker

Advantages:

- Containers are lightweight.
- Containers start quickly.
- Images make environments reproducible.
- Each service can be isolated in its own container.
- Easier to rebuild and deploy the infrastructure.

Disadvantages:

- Containers share the host kernel.
- Isolation is different from that provided by a complete virtual machine.

In this project, a virtual machine provides the Linux environment in which Docker runs, while Docker separates NGINX, WordPress and MariaDB into individual containers.

---

## Secrets vs Environment Variables

Environment variables are useful for configuration that is not sensitive.

Examples in this project include:

```env
MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser
MYSQL_HOST=mariadb
DOMAIN_NAME=anruiz-d.42.fr
```

Passwords should not be stored directly in environment variables.

Instead, this project stores them in secret files such as:

```text
db_password.txt
db_root_password.txt
wp_admin_password.txt
wp_user_password.txt
```

Docker Compose mounts these files only inside the containers that require them, under `/run/secrets/`.

This reduces accidental exposure and prevents passwords from being stored directly inside the Compose file or `.env`.

In short:

```text
Environment Variables -> non-sensitive configuration
Secrets               -> sensitive information such as passwords
```

---

## Docker Network vs Host Network

The project uses a Docker bridge network called:

```text
inception
```

All three containers are connected to it.

A Docker bridge network provides isolation from the host network and includes internal DNS resolution.

For example:

```text
mariadb
wordpress
nginx
```

can be used as hostnames inside the network.

This is why NGINX can use:

```nginx
fastcgi_pass wordpress:9000;
```

and WordPress can connect to:

```text
mariadb:3306
```

With **host networking**, a container uses the network namespace of the host directly.

This removes part of the network isolation and can also create conflicts between services trying to use the same ports.

Using a dedicated Docker network is therefore more appropriate for this infrastructure because the services remain isolated and only NGINX needs to expose port `443`.

---

## Docker Volumes vs Bind Mounts

Both Docker volumes and bind mounts can persist data outside the lifecycle of a container.

### Docker volumes

Docker volumes are declared and managed through Docker or Docker Compose.

They are independent from the container itself, which means deleting and recreating a container does not necessarily delete its data.

### Bind mounts

A bind mount directly maps a specific directory from the host filesystem into a container.

For example:

```text
Host directory -> Container directory
```

The Inception infrastructure stores persistent data under:

```text
/home/anruiz-d/data/
```

with separate directories for:

```text
/home/anruiz-d/data/mariadb
/home/anruiz-d/data/wordpress
```

These directories are used by the volumes declared in Docker Compose so that MariaDB databases and WordPress files survive container recreation.

The relevant container paths are:

```text
MariaDB:
    /var/lib/mysql

WordPress:
    /var/www/html
```

This means a normal:

```bash
docker compose down
```

can remove the containers while the website and database data remain available for the next execution.

---

## Resources

Resources used during the development of the project include:

- Docker Engine documentation.
- Docker Compose documentation.
- Official Docker installation instructions for Debian:
  `https://docs.docker.com/engine/install/debian/`
- NGINX configuration documentation.
- MariaDB documentation.
- WordPress documentation.
- WP-CLI:
  `https://wp-cli.org/`

WP-CLI is downloaded inside the WordPress image from its official build repository.

### Use of AI

AI tools were used as a learning and support resource during the development of the project.

They were used to help:

- Understand Docker and Docker Compose concepts.
- Clarify the behaviour of Dockerfiles and container processes.
- Understand Docker networking and service-name resolution.
- Analyse errors encountered while configuring the services.
- Review commands and configuration choices.
- Structure and improve the project documentation.

The generated explanations were reviewed and the commands and configurations were manually tested in the virtual machine before being included in the project.
