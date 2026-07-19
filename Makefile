# Variables
DOCKER_COMPOSE = docker-compose
NPM = npm

# Backend
.PHONY: install
install:
	$(NPM) install

.PHONY: dev
dev:
	$(NPM) run dev

.PHONY: build
build:
	$(NPM) run build

.PHONY: lint
lint:
	$(NPM) run lint

.PHONY: test
test:
	$(NPM) run test

.PHONY: test:e2e
test:e2e:
	$(NPM) run test:e2e

.PHONY: test:coverage
test:coverage:
	$(NPM) run test:coverage

# Docker
.PHONY: docker:build
docker:build:
	$(DOCKER_COMPOSE) build

.PHONY: docker:up
docker:up:
	$(DOCKER_COMPOSE) up -d

.PHONY: docker:down
docker:down:
	$(DOCKER_COMPOSE) down

.PHONY: docker:logs
docker:logs:
	$(DOCKER_COMPOSE) logs -f

# Base de datos
.PHONY: db:migrate
db:migrate:
	$(NPM) run migrate

.PHONY: db:seed
db:seed:
	$(NPM) run seed

.PHONY: db:reset
db:reset:
	$(NPM) run migrate:reset

# Utilidades
.PHONY: clean
clean:
	rm -rf dist/ node_modules/ .next/

.PHONY: tidy
tidy:
	$(NPM) prune && $(NPM) audit fix
