# ---- config ---------------------------------------------------------------
SHELL			:= /bin/bash
.DEFAULT_GOAL	:= all

export DOCKER_BUILDKIT = 1
export COMPOSE_DOCKER_CLI_BUILD = 1

COMPOSE_FILE	:= srcs/docker-compose.yml
ENV_FILE		:= srcs/.env
COMPOSE			:= docker compose --env-file $(ENV_FILE) -f $(COMPOSE_FILE)

# Resolve the effective data directory from the .env file
EFFECTIVE_DATA_DIR := $(shell bash -lc '\
  set -a; . <(sed "s/\r$$//" srcs/.env); set +a; \
  p="$${HOST_DATA_DIR}"; \
  p="$$(printf "%s" "$$p" | tr -d "\r")"; \
  eval "p=$$p"; \
  [ -n "$$p" ] || p="$$HOME/data"; \
  printf "%s" "$$p" \
')

all: up

# ---- run -------------------------------------------------------------------
up:
	@mkdir -p $(EFFECTIVE_DATA_DIR)/mariadb
	@mkdir -p $(EFFECTIVE_DATA_DIR)/wordpress
	@HOST_DATA_DIR='$(EFFECTIVE_DATA_DIR)' $(COMPOSE) up -d --build

down:
	@HOST_DATA_DIR='$(EFFECTIVE_DATA_DIR)' $(COMPOSE) down --remove-orphans

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

.PHONY: all build up down clean fclean re
