# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Makefile                                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: anruiz-d <anruiz-d@student.42madrid.com    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2026/10/15 14:30:08 by anruiz-d          #+#    #+#              #
#    Updated: 2026/10/21 16:49:27 by anruiz-d         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

NAME			=	inception

COMPOSE_FILE	=	srcs/docker-compose.yml
ENV_FILE		=	srcs/.env

COMPOSE			=	docker compose -p $(NAME) \
					--env-file $(ENV_FILE) \
					-f $(COMPOSE_FILE)
# docker flags #
# -p -> project name -> para agrupar los servicios bajo el nombre del proyecto
# -f -> file  -> para indicar que archivo debe utilizar, sin eso busca nombres convencionales

# ================ #
# Values from .env #
# ================ #

LOGIN			:= $(shell sed -n 's/^LOGIN=//p' $(ENV_FILE))
DOMAIN_NAME		:= $(shell sed -n 's/^DOMAIN_NAME=//p' $(ENV_FILE))
SSH_USER		:= $(shell sed -n 's/^SSH_USER=//p' $(ENV_FILE))
SSH_HOST		:= $(shell sed -n 's/^SSH_HOST=//p' $(ENV_FILE))
SSH_PORT		:= $(shell sed -n 's/^SSH_PORT=//p' $(ENV_FILE))
SOCKS_PORT		:= $(shell sed -n 's/^SOCKS_PORT=//p' $(ENV_FILE))

# ================ #
#	   PATHS       #
# ================ #

REMOTE_DIR		=	/home/$(SSH_USER)/inception
DATA_ROOT		=	/home/$(LOGIN)
DATA_DIR		=	$(DATA_ROOT)/data
MARIADB_DATA	=	$(DATA_DIR)/mariadb
WORDPRESS_DATA	=	$(DATA_DIR)/wordpress

# ================ #
#	    SSH        #
# ================ #

SSH_VM			=	ssh -p $(SSH_PORT) $(SSH_USER)@$(SSH_HOST)
SSH_VM_TTY		=	ssh -tt -p $(SSH_PORT) $(SSH_USER)@$(SSH_HOST)
RSYNC_SSH		=	ssh -p $(SSH_PORT)
SSH_KEY			=	$(HOME)/.ssh/id_ed25519
SSH_PUB_KEY		=	$(SSH_KEY).pub

# SSH FLAGS
# -tt -> Fuerza la asignacion de una terminal incluso si ssh no detecta una terminal local

# ================ #
#   SOCKS TUNNEL   #
# ================ #

TUNNEL_SOCKET	=	/tmp/$(NAME)_socks

# ================ #
#    MAKE RULES    #
# ================ #

all:
	$(MAKE)	prepare
	$(MAKE)	sync
	$(MAKE) deploy
	$(MAKE) tunnel

# =================== #
# 		  Env		  #
# =================== #

env:
	@if [ ! -f "$(ENV_FILE)" ]; then \
		cp srcs/.env.example $(ENV_FILE); \
		echo "Created $(ENV_FILE) from template"; \
		echo "Edit $(ENV_FILE) before running make"; \
	fi

# ================ #
#  MAKE ssh-setup  #
# ================ #

ssh-key:
	if [ ! -f "$(SSH_KEY)" ]; then \
		echo "Generating SSH key..."; \
		mkdir -p "$(HOME)/.ssh"; \
		chmod 700 "$(HOME)/.ssh"; \
		ssh-keygen -t ed25519 -f "$(SSH_KEY)" -N ""; \
	else \
		echo "SSH key already exists"; \
	fi 
# SSH FLAGS
# -t -> especifica el tipo de ssh key que generara
# -f -> indica donde guardará la clave y con que nombre
# -N -> establece la contraseña que protegerá la clave privada

ssh-copy-key: ssh-key
	echo "Copying SSH public key to VM..."
	ssh-copy-id \
		-i "$(SSH_PUB_KEY)" \
		-p "$(SSH_PORT)" \
		$(SSH_USER)@$(SSH_HOST)
# SSH COPY FLAGS
# -i -> indica el archivo de clave pública que quieres instalar en la máquina virtual
# -p -> Indica el puerto SSH al que conectarse.

ssh-setup: ssh-copy-key
	ssh \
		-o BatchMode=yes \
		-p $(SSH_PORT) \
		$(SSH_USER)@$(SSH_HOST) 
# SSH SETUP FLAGS
# -o 		-> especifica una opcion de configuracion de ssh
# BatchMode -> indica que será en modo no interactivo, evitando que SSH solicite contraseñas o confirmaciones interactivas de autenticación
# -p 		-> Indica el puerto SSH al que conectarse.

# ================ #
#   MAKE vm-setup  #
# ================ #

vm-setup: 
	$(SSH_VM_TTY) '\
		set -e; \
		echo "Requesting sudo privileges..."; \
		sudo -v; \
		echo "Removing old/broken Docker repository configuration..."; \
		sudo rm -f \
			/etc/apt/sources.list.d/docker.sources \
			/etc/apt/sources.list.d/docker.list;	\
		\
		echo "Updating Debian repositories..."; \
		sudo apt-get update; \
		\
		echo "Installing required tools..."; \
		sudo apt-get install -y \
			ca-certificates \
			curl \
			rsync; \
		\
		echo "Configuring Docker repository..."; \
		sudo install -m 0755 -d /etc/apt/keyrings; \
		\
		sudo curl -fsSL \
			https://download.docker.com/linux/debian/gpg \
			-o /etc/apt/keyrings/docker.asc; \
		\
		sudo chmod 644 /etc/apt/keyrings/docker.asc; \
		\
		. /etc/os-release; \
		ARCH=$$(dpkg --print-architecture); \
		\
		printf "%s\n" \
			"Types: deb" \
			"URIs: https://download.docker.com/linux/debian" \
			"Suites: $$VERSION_CODENAME" \
			"Components: stable" \
			"Architectures: $$ARCH" \
			"Signed-By: /etc/apt/keyrings/docker.asc" | \
			sudo tee /etc/apt/sources.list.d/docker.sources \
			>/dev/null; \
		\
		echo "Updating repositories with Docker repository..."; \
		sudo apt-get update; \
		\
		echo "Installing Docker..."; \
		sudo apt-get install -y \
			docker-ce \
			docker-ce-cli \
			containerd.io \
			docker-buildx-plugin \
			docker-compose-plugin; \
		\
		echo "Starting Docker..."; \
		sudo systemctl enable --now docker; \
		\
		echo "Adding user to docker group..."; \
		sudo usermod -aG docker $(SSH_USER); \
		\
		echo "Configuring /etc/hosts..."; \
		sudo sed -i "/$(DOMAIN_NAME)/d" /etc/hosts; \
		echo "127.0.0.1 $(DOMAIN_NAME)" | \
			sudo tee -a /etc/hosts >/dev/null; \
		\
		echo "Creating directories..."; \
		sudo mkdir -p \
			$(DATA_ROOT) \
			$(MARIADB_DATA) \
			$(WORDPRESS_DATA); \
		\
		sudo chown -R \
			$(SSH_USER):$(SSH_USER) \
			$(DATA_ROOT); \
		\
		mkdir -p $(REMOTE_DIR); \
		\
		sudo docker --version; \
		sudo docker compose version; \
		echo "VM setup completed." \
		\
	'
# ================ #
#      Secrets     #
# ================ #	

secrets:
	@mkdir -p secrets
	@chmod 700 secrets
	@for f in \
		db_password.txt \
		db_root_password.txt \
		wp_admin_password.txt \
		wp_user_password.txt; do \
		if [ ! -s "secrets/$$f" ]; then \
			umask 077; \
			openssl rand -hex 32 > "secrets/$$f"; \
			echo "Generated secrets/$$f"; \
		fi; \
	done
	@chmod 600 secrets/*.txt

# =================== #
# Prepare Directories #
# =================== #

prepare: secrets
	@echo "Checking remote directories..."
	$(SSH_VM) '\
		mkdir -p \
			$(REMOTE_DIR) \
			$(MARIADB_DATA) \
			$(WORDPRESS_DATA) \
	'
# =================== #
# SYNC HOST -> VM #
# =================== #

sync:
	@echo "Synchronizing project with VM..."
	rsync -az --delete \
		--exclude '.git/' \
		--exclude '.DS_Store' \
		--exclude 'inception' \
		-e "$(RSYNC_SSH)" \
		./ $(SSH_USER)@$(SSH_HOST):$(REMOTE_DIR)/

# =================== #
# START INCEPTION #
# =================== #

deploy:
	@echo "Building and starting Inception..."
	$(SSH_VM) 'cd $(REMOTE_DIR) && \
		$(COMPOSE) up -d --build'

up:
	@$(MAKE) prepare
	@$(MAKE) sync
	@$(MAKE) deploy

# =================== #
# STOP INCEPTION #
# =================== #

down:
	$(SSH_VM) 'cd $(REMOTE_DIR) && \
		$(COMPOSE) down'

# =================== #
# SSH INTO VM #
# =================== #

ssh:
	$(SSH_VM)

# =================== #
# CHECK VM /etc/hosts #
# =================== #

hosts-check:
	$(SSH_VM) 'grep "$(DOMAIN_NAME)" /etc/hosts'

# =================== #
# SOCKS TUNNEL #
# =================== #

tunnel:
	@if ssh \
		-S $(TUNNEL_SOCKET) \
		-O check \
		-p $(SSH_PORT) \
		$(SSH_USER)@$(SSH_HOST) \
		>/dev/null 2>&1; then \
		echo "SOCKS tunnel already running:"; \
		echo "127.0.0.1:$(SOCKS_PORT)"; \
	else \
		rm -f $(TUNNEL_SOCKET); \
		ssh -f -N -M \
			-S $(TUNNEL_SOCKET) \
			-o ExitOnForwardFailure=yes \
			-o ServerAliveInterval=30 \
			-o ServerAliveCountMax=3 \
			-p $(SSH_PORT) \
			-D 127.0.0.1:$(SOCKS_PORT) \
			$(SSH_USER)@$(SSH_HOST); \
		echo "SOCKS tunnel created:"; \
		echo "127.0.0.1:$(SOCKS_PORT)"; \
	fi

tunnel-stop:
	-ssh \
		-S $(TUNNEL_SOCKET) \
		-O exit \
		-p $(SSH_PORT) \
		$(SSH_USER)@$(SSH_HOST) \
		>/dev/null 2>&1
	@rm -f $(TUNNEL_SOCKET)
	@echo "SOCKS tunnel stopped."

# =================== #
# STATUS #
# =================== #

status:
	$(SSH_VM) '\
		cd $(REMOTE_DIR) && \
		$(COMPOSE) ps \
	'
# =================== #
# LOGS #
# =================== #

logs:
	$(SSH_VM) 'cd $(REMOTE_DIR) && $(COMPOSE) logs'

# =================== #
# CLEAN #
# =================== #

clean:
	$(SSH_VM) 'cd $(REMOTE_DIR) \
	&& $(COMPOSE) down --remove-orphans'

fclean: tunnel-stop
	-$(SSH_VM) 'cd $(REMOTE_DIR) && \
		$(COMPOSE) down --rmi all --volumes \
		--remove-orphans'
	$(SSH_VM_TTY) 'sudo rm -rf $(DATA_DIR)'
	$(SSH_VM) 'rm -rf $(REMOTE_DIR)'

re: fclean all

.PHONY: \
	all ssh-key ssh-copy-key ssh-setup vm-setup secrets env prepare \
	sync deploy up down ssh hosts-check tunnel tunnel-stop status logs \
	clean fclean re