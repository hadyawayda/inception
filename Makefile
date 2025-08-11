# ---- config ---------------------------------------------------------------
SHELL			:= /bin/bash
.DEFAULT_GOAL	:= all

export DOCKER_BUILDKIT = 1
export COMPOSE_DOCKER_CLI_BUILD = 1

COMPOSE_FILE	:= srcs/docker-compose.yml
ENV_FILE		:= srcs/.env
COMPOSE			:= docker compose --env-file $(ENV_FILE) -f $(COMPOSE_FILE)

# Buildx: always use the built-in local BuildKit (builder "default")
BUILDX_B		:= docker buildx build --builder default

all: clean builder build up

# ---- Buildx: use the built-in 'default' (local BuildKit), never create/ls ---
builder:
	@$(BUILDX_B) inspect --bootstrap >/dev/null 2>&1 || true

# Build only MariaDB via bake (load into local Docker for compose to use)
build: builder
	@cd srcs && \
	CTX="$$PWD/requirements/mariadb" && \
	docker buildx --builder default bake --allow=fs.read=.. -f docker-compose.yml \
		--load \
		--set mariadb.context="$$CTX" \
		mariadb

# ---- run -------------------------------------------------------------------
up:
	@$(COMPOSE) up -d mariadb

down:
	@$(COMPOSE) down --remove-orphans

# ---- cleanup --------------------------------------------------------------
clean: down
	@echo "Stopping all running containers..."
	@docker stop $(docker ps -q) 2>/dev/null || true
	@echo "Pruning unused Docker resources..."
	@- $(BUILDX_B) prune -af 2>/dev/null || true
	@- docker builder prune -af 2>/dev/null || true
	@- docker system prune -af 2>/dev/null || true

fclean: clean
	@docker volume rm -f srcs_mariadb_data || true

re: down all

.PHONY: all  \
        builder build build-all up down clean fclean re
