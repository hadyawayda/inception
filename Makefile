# ---- config ---------------------------------------------------------------
SHELL			:= /bin/bash
.DEFAULT_GOAL	:= all

# ---- variables -------------------------------------------------------------
export DOCKER_BUILDKIT = 1
export COMPOSE_DOCKER_CLI_BUILD = 1

# ---- paths ------------------------------------------------------------------
COMPOSE			:= docker compose -f srcs/docker-compose.yml --progress tty
DB				:= docker exec -it mariadb mysql -u root -p"hawayda"

# ---- targets ---------------------------------------------------------------
all: up

# ---- run -------------------------------------------------------------------
up:
	@$(COMPOSE) up -d --build

down:
	@$(COMPOSE) down --remove-orphans

mariadb:
	@$(COMPOSE) build mariadb
	@$(COMPOSE) up -d mariadb

wordpress:
	@$(COMPOSE) build wordpress
	@$(COMPOSE) up -d wordpress

db:
	@$(DB)
	
# ---- cleanup --------------------------------------------------------------
clean: down
	@echo "Stopping all running containers..."
	@docker stop $(docker ps -q) 2>/dev/null || true
	@echo "Pruning unused Docker resources..."
	@- docker system prune -af 2>/dev/null || true

fclean: clean
	@docker volume rm -f inception_mariadb_data || true
	@docker volume rm -f inception_wp_data || true

re: clean all

.PHONY: all build up down clean fclean re db
