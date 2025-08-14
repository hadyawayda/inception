# ---- config ---------------------------------------------------------------
SHELL			:= /bin/bash
.DEFAULT_GOAL	:= all

# ---- variables -------------------------------------------------------------
export DOCKER_BUILDKIT = 1
export COMPOSE_DOCKER_CLI_BUILD = 1

# ---- paths ------------------------------------------------------------------
COMPOSE			:= docker compose -f srcs/docker-compose.yml
DB				:= docker exec -it mariadb mysql -u root -p"hawayda"

# ---- targets ---------------------------------------------------------------
all: up

# ---- run -------------------------------------------------------------------
up:
	@mkdir -p /home/${USER}/data/mariadb
	@mkdir -p /home/${USER}/data/wordpress
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

db:
	@$(DB)
	
# ---- cleanup --------------------------------------------------------------
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

re: clean all

.PHONY: all build up down clean fclean re db
