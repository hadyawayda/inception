# ---- config ---------------------------------------------------------------
SHELL := /bin/bash
.DEFAULT_GOAL := all

export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

COMPOSE_FILE := srcs/docker-compose.yml
ENV_FILE     := srcs/.env
COMPOSE      := docker compose --env-file $(ENV_FILE) -f $(COMPOSE_FILE)

# Buildx: always use the built-in local BuildKit (builder "default")
BUILDX   := docker buildx
BUILDER  := default
BUILDX_B := $(BUILDX) --builder $(BUILDER)

PLATFORM ?=   # optional: linux/amd64 or linux/arm64

# Fully expand HOST_DATA_DIR from srcs/.env (resolves ${LOGIN}/${HOME}, strips CRLF)
EFFECTIVE_DATA_DIR := $(shell bash -lc '\
  set -a; . <(sed "s/\r$$//" srcs/.env); set +a; \
  p="$${HOST_DATA_DIR}"; \
  p="$$(printf "%s" "$$p" | tr -d "\r")"; \
  eval "p=$$p"; \
  [ -n "$$p" ] || p="$$HOME/data"; \
  printf "%s" "$$p" \
')

# Absolute build context for mariadb (prevents bake path confusion)
MARIADB_CTX := $(CURDIR)/srcs/requirements/mariadb

all: clean preflight ensure-envfile ensure-secrets ensure-data-dir builder build up

# Ensure docker is available
preflight:
	@command -v docker >/dev/null || { echo "ERROR: docker not found"; exit 1; }
	@docker version >/dev/null

# Require srcs/.env to exist (do NOT create it)
ensure-envfile:
	@[ -f $(ENV_FILE) ] || { \
		echo "ERROR: $(ENV_FILE) is missing. Create it and set HOST_DATA_DIR, etc."; \
		exit 1; \
	}

# Secrets (create if missing)
ensure-secrets:
	@mkdir -p secrets
	@[ -f secrets/db_root_password.txt ] || (umask 077; echo "change-me-strong-root-pass" > secrets/db_root_password.txt)
	@[ -f secrets/db_password.txt ]      || (umask 077; echo "change-me-strong-wp-pass"   > secrets/db_password.txt)

# Create data dir (from HOST_DATA_DIR in srcs/.env)
ensure-data-dir: ensure-envfile
	@dir='$(EFFECTIVE_DATA_DIR)'; \
	mkdir -p "$$dir/mariadb" 2>/dev/null || { \
	  echo "ERROR: cannot create $$dir/mariadb (permission denied)."; \
	  echo "       Fix HOST_DATA_DIR in $(ENV_FILE) or pick a writable path."; \
	  exit 1; \
	}
	@echo "Using data dir: $(EFFECTIVE_DATA_DIR)"

# ---- Buildx: use the built-in 'default' (local BuildKit), never create/ls ---
builder:
	@$(BUILDX) --builder $(BUILDER) inspect --bootstrap >/dev/null 2>&1 || true

# Build only MariaDB via bake (load into local Docker for compose to use)
build: builder
	@cd srcs && \
	CTX="$$PWD/requirements/mariadb" && \
	docker buildx --builder $(BUILDER) bake --allow=fs.read=.. -f docker-compose.yml \
		--load \
		--set mariadb.context="$$CTX" \
		mariadb

# ---- run -------------------------------------------------------------------
up:
	@HOST_DATA_DIR='$(EFFECTIVE_DATA_DIR)' $(COMPOSE) up -d mariadb

down:
	@HOST_DATA_DIR='$(EFFECTIVE_DATA_DIR)' $(COMPOSE) down --remove-orphans

# ---- cleanup --------------------------------------------------------------
clean: down
	@- $(BUILDX_B) prune -af 2>/dev/null || true
	@- docker builder prune -af 2>/dev/null || true
	@- docker system prune -af 2>/dev/null || true

fclean: clean
	@- docker image rm inception-mariadb:1.0 2>/dev/null || true

re: down all

.PHONY: all preflight ensure-envfile ensure-secrets ensure-data-dir \
        builder build build-all up down clean fclean re
