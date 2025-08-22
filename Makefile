# ---- config ----------------------------------------------------------------
SHELL			:= /bin/bash
.DEFAULT_GOAL	:= all

# ---- variables -------------------------------------------------------------
export DOCKER_BUILDKIT = 1
export COMPOSE_DOCKER_CLI_BUILD = 1

# ---- compose ---------------------------------------------------------------
COMPOSE			:= docker compose -f srcs/docker-compose.yml
COMPOSE_AWS		:= docker compose -f srcs/docker-compose.aws.yml
COMPOSE_LOCAL	:= docker compose -f srcs/docker-compose.local.yml
DB				:= docker exec -it mariadb mysql -u root -p"hawayda"

# ---- helpers ---------------------------------------------------------------
UPDATE_SITEURL	:= docker exec -it wordpress wp option update siteurl "https://localhost:8443" --allow-root --path=/var/www/html
UPDATE_HOME		:= docker exec -it wordpress wp option update home "https://localhost:8443" --allow-root --path=/var/www/html
RESTORED_URL	:= docker exec -it wordpress wp option update siteurl "https://localhost" --allow-root --path=/var/www/html
RESTORED_HOME	:= docker exec -it wordpress wp option update home "https://localhost " --allow-root --path=/var/www/html
GET_SITEURL		:= docker exec -it wordpress wp option get siteurl --allow-root --path=/var/www/html
GET_HOME		:= docker exec -it wordpress wp option get home --allow-root --path=/var/www/html

# ---- targets ---------------------------------------------------------------
all: up

# ---- commands --------------------------------------------------------------
up:
	@$(COMPOSE) up -d --build

down:
	@$(COMPOSE) down --remove-orphans

mariadb:
	@docker stop mariadb 2>/dev/null || true
	@docker rm -f mariadb 2>/dev/null || true
	@docker rmi -f mariadb 2>/dev/null || true
	@docker builder prune -af 2>/dev/null || true
	@$(COMPOSE) build --no-cache mariadb
	@$(COMPOSE) up -d mariadb

wordpress:
	@docker stop wordpress 2>/dev/null || true
	@docker rm -f wordpress 2>/dev/null || true
	@docker rmi -f wordpress 2>/dev/null || true
	@docker builder prune -af 2>/dev/null || true
	@$(COMPOSE) build --no-cache wordpress
	@$(COMPOSE) up -d wordpress

nginx:
	@docker stop nginx 2>/dev/null || true
	@docker rm -f nginx 2>/dev/null || true
	@docker rmi -f nginx 2>/dev/null || true
	@docker builder prune -af 2>/dev/null || true
	@$(COMPOSE) build --no-cache nginx
	@$(COMPOSE) up -d nginx

db:
	@$(DB)

# ---- cleanup commands ------------------------------------------------------
clean: down
	@echo "Stopping all running containers..."
	@docker stop $(docker ps -q) 2>/dev/null || true
	@echo "Removing all stopped containers..."
	@docker builder prune -af 2>/dev/null || true
	@echo "Removing all containers..."
	@docker rmi -f $(docker images -q) 2>/dev/null || true
	@echo "Pruning unused Docker resources..."
	@- docker system prune -af 2>/dev/null || true

fclean: clean
	@docker volume rm -f inception_mariadb_data || true
	@docker volume rm -f inception_wp_data || true
	@- docker system prune -af 2>/dev/null || true

create-directories:
	@mkdir -p /home/hawayda/data/mariadb
	@mkdir -p /home/hawayda/data/wordpress

remove-directories:
	@docker rm -f wordpress mariadb 2>/dev/null || true
	@docker run --rm -v /home/hawayda/data:/data alpine sh -c "rm -rf /data/*"
	@rm -rf /home/hawayda/data

local:
	@$(COMPOSE_LOCAL) up -d --build
	@$(UPDATE_SITEURL)
	@$(UPDATE_HOME)

ec2:
	@$(COMPOSE_AWS) up -d --build

info:
	@$(GET_SITEURL)
	@$(GET_HOME)

set-local:
	@$(UPDATE_SITEURL)
	@$(UPDATE_HOME)

re: clean all

.PHONY: all build up down clean fclean re db
