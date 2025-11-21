NAME = inception

COMPOSE = docker compose
COMPOSE_FILE = srcs/docker-compose.yml

all: up

up:
	$(COMPOSE) -f $(COMPOSE_FILE) up -d --build

down:
	$(COMPOSE) -f $(COMPOSE_FILE) down

clean:
	$(COMPOSE) -f $(COMPOSE_FILE) down -v

fclean: down clean
	@docker system prune --volumes -af
	@docker volume prune -af

ps:
	@$(COMPOSE) -f $(COMPOSE_FILE) ps

re: clean up

.PHONY: all up down clean re
