NAME 		=	inception

COMPOSE_FILE 	=	srcs/docker-compose.yml
ENV_FILE 	=	srcs/.env
COMPOSE 	=	docker compose -p $(NAME) --env-file $(ENV_FILE) -f $(COMPOSE_FILE)
LOGIN		:=	$(shell sed -n 's/^LOGIN=//p' $(ENV_FILE))

SRCS		=	$(shell find srcs -type f)

DATA_DIR	=	/home/$(LOGIN)/data
MARIADB_DATA	=	$(DATA_DIR)/mariadb
WORDPRESS_DATA	=	$(DATA_DIR)/wordpress

all:	$(NAME)

$(NAME): $(SRCS) | prepare
	$(COMPOSE) up -d --build
	touch $(NAME)

prepare:
	mkdir -p $(MARIADB_DATA)
	mkdir -p $(WORDPRESS_DATA)

up: prepare
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down
	rm -f $(NAME)

clean:
	$(COMPOSE) down --remove-orphans
	rm -f $(NAME)

fclean: clean
	$(COMPOSE) down --rmi all --volumes --remove-orphans
	sudo rm -rf $(DATA_DIR)

re: fclean all

.PHONY: all prepare up down clean fclean re
