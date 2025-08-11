COMPOSE := docker compose -f srcs/docker-compose.yml
BUILDX  := docker buildx
BUILDER := inception-builder
# Optionally set: make PLATFORM=linux/amd64  (or linux/arm64)
PLATFORM ?=

.PHONY: all builder build up down clean fclean re

all: builder build up

builder:
	@$(BUILDX) ls | grep -q '^$(BUILDER)\b' || $(BUILDX) create --name $(BUILDER) --driver docker-container
	@$(BUILDX) use $(BUILDER)
	@$(BUILDX) inspect --bootstrap >/dev/null

build: builder
ifneq ($(PLATFORM),)
	$(BUILDX) bake -f srcs/docker-compose.yml --load --set *.platform=$(PLATFORM)
else
	$(BUILDX) bake -f srcs/docker-compose.yml --load
endif

up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

clean: down
	docker system prune -f

fclean: down
	- docker volume rm $$(docker volume ls -q | grep -E '^inception_') 2>/dev/null || true
	- docker image rm inception-mariadb:1.0 2>/dev/null || true

re: down all
