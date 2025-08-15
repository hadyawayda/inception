# ---- config ----------------------------------------------------------------
SHELL			:= /bin/bash
.DEFAULT_GOAL	:= all

# ---- variables -------------------------------------------------------------
export DOCKER_BUILDKIT = 1
export COMPOSE_DOCKER_CLI_BUILD = 1

# ---- paths -----------------------------------------------------------------
COMPOSE			:= docker compose -f srcs/docker-compose.yml
DB				:= docker exec -it mariadb mysql -u root -p"hawayda"

# ---- targets ---------------------------------------------------------------
all: up

# ---- commands --------------------------------------------------------------
up:	create-directories
	@$(COMPOSE) up -d --build

down:
	@$(COMPOSE) down --remove-orphans

mariadb: create-directories
	@docker stop mariadb 2>/dev/null || true
	@docker rm -f mariadb 2>/dev/null || true
	@docker rmi -f mariadb 2>/dev/null || true
	@docker builder prune -af 2>/dev/null || true
	@$(COMPOSE) build --no-cache mariadb
	@$(COMPOSE) up -d mariadb

wordpress: create-directories
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

fclean: clean remove-directories
	@docker volume rm -f inception_mariadb_data || true
	@docker volume rm -f inception_wp_data || true

create-directories:
	@mkdir -p /home/${USER}/data/mariadb
	@mkdir -p /home/${USER}/data/wordpress

remove-directories:
	@docker rm -f wordpress mariadb 2>/dev/null || true
	@docker run --rm -v /home/${USER}/data:/data alpine sh -c "rm -rf /data/*"
	@rm -rf /home/${USER}/data

re: clean all

.PHONY: all build up down clean fclean re db
