NAME 		=	inception

COMPOSE_FILE 	=	srcs/docker-compose.yml
ENV_FILE 		=	srcs/.env
COMPOSE 		=	docker compose -p $(NAME) --env-file $(ENV_FILE) -f $(COMPOSE_FILE)
LOGIN			:=	$(shell sed -n 's/^LOGIN=//p' $(ENV_FILE))
HOST_IP			:=	$(shell sed -n 's/^HOST_IP=//p' $(ENV_FILE))
HOST_PORT		:=	$(shell sed -n 's/^HOST_PORT=//p' $(ENV_FILE))
LOCAL_IP		:=	$(shell sed -n 's/^LOCAL_IP=//p' $(ENV_FILE))
LOCAL_PORT		:=	$(shell sed -n 's/^LOCAL_PORT=//p' $(ENV_FILE))
SRCS			=	$(shell find srcs -type f)

REMOTE_DIR		=	/home/$(LOGIN)/inception
DATA_DIR		=	/home/$(LOGIN)/data
MARIADB_DATA	=	$(DATA_DIR)/mariadb
WORDPRESS_DATA	=	$(DATA_DIR)/wordpress

SSH_USER		=	$(LOGIN)
SSH_PORT		=	$(shell sed -n 's/^SSH_PORT=//p' $(ENV_FILE))

SSH_VM			:=	ssh -p $(SSH_PORT) $(SSH_USER)@$(LOCAL_IP)
RSYNC_SSH		:=	ssh -p $(SSH_PORT)

TUNNEL_SOCKET	:=	/tmp/tunnel_socket

all:	$(NAME)

$(NAME): secrets
	$(SSH_VM) 'mkdir -p $(REMOTE_DIR)' prepare
	rsync -az --delete -e '$(RSYNC_SSH)' ./ $(SSH_USER)@$(LOCAL_IP):$(DATA_DIR)
	$(SSH_VM) 'cd $(DATA_DIR) && $(COMPOSE) up -d --build'
	$(SSH_VM)
	touch $(NAME)

prepare:
	mkdir -p $(MARIADB_DATA)
	mkdir -p $(WORDPRESS_DATA)

up: prepare
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down
	rm -f $(NAME)

ssh:
	$(SSH_VM)

secrets:
	@mkdir -p secrets
	@chmod 700 secrets
	@for f in db_password.txt db_root_password.txt wp_admin_password.txt wp_user_password.txt; do \
		if [ ! -s "secrets/$$f" ]; then \
			umask 077; \
			openssl rand -hex 32 > "secrets/$$f"; \
			echo "Generated secrets/$$f"; \
		fi; \
	done
	@chmod 600 secrets/*.txt

tunnel:
	ssh -f -N -M \
		-S $(TUNNEL_SOCKET) \
		-o ExitOnForwardFailure=yes \
		-p $(SSH_PORT) \
		-L $(LOCAL_PORT):$(LOCAL_IP):$(HOST_PORT) \
		$(SSH_USER)@$(HOST_IP)

tunnel-stop:
	-ssh -S $(TUNNEL_SOCKET) -O exit -p $(SSH_PORT) $(SSH_USER)@$(HOST_IP)
	rm -f $(TUNNEL_SOCKET)

clean:
	$(SSH_VM) '$(COMPOSE) down --remove-orphans'
	$(SSH_VM) 'rm -f $(NAME)'

fclean: clean
	$(SSH_VM) '$(COMPOSE) down --rmi all --volumes --remove-orphans'
	$(SSH_VM) 'sudo rm -rf $(DATA_DIR)'

re: fclean all

.PHONY: all prepare up down clean fclean re
