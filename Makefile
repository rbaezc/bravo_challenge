.PHONY: help first-run setup db-up db-down db-setup migrate seed run test clean docker-build deploy

# Default task: show help
help:
	@echo "Bravo Credit Engine - Makefile"
	@echo ""
	@echo "Available commands:"
	@echo "  make first-run    - One command: DB + deps + assets + migrate + seed"
	@echo "  make setup        - Install dependencies and prepare assets"
	@echo "  make db-up        - Start local PostgreSQL via docker compose (waits until ready)"
	@echo "  make db-down      - Stop local PostgreSQL"
	@echo "  make db-setup     - Create database, run migrations and seed demo users"
	@echo "  make migrate      - Run database migrations"
	@echo "  make seed         - Run database seeds"
	@echo "  make run          - Start the Phoenix server"
	@echo "  make test         - Run the test suite"
	@echo "  make docker-build - Build the production Docker image"
	@echo "  make deploy       - Apply Kubernetes manifests (k8s/)"
	@echo "  make clean        - Clean build artifacts and dependencies"
	@echo ""

# One-shot bootstrap: start the DB (and wait for it), install deps/assets,
# create the database, migrate and seed. Then `make run`.
first-run: db-up setup db-setup
	@echo ""
	@echo "Listo. Ejecuta 'make run' y abre http://localhost:4000"

setup:
	mix deps.get
	mix assets.setup
	mix assets.build

db-up:
	docker compose up -d --wait

db-down:
	docker compose down

db-setup:
	mix ecto.create
	mix ecto.migrate
	mix run priv/repo/seeds.exs

migrate:
	mix ecto.migrate

seed:
	mix run priv/repo/seeds.exs

run:
	mix phx.server

test:
	mix test

docker-build:
	docker build -t bravo-app:latest .

deploy:
	kubectl apply -f k8s/

clean:
	mix clean
	rm -rf _build/
	rm -rf deps/
