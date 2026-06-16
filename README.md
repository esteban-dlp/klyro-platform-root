# Klyro Platform - Docker Development Setup

This folder manages the full local development environment using Docker Compose.

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running
- Node.js 20+ (for running services outside Docker)

## Quick Start

```bash
cd root

# Copy example env files if you haven't already
cp .env.frontend.example .env.frontend
cp .env.backend.example .env.backend
cp .env.database.example .env.database

# Start all services
docker compose up --build
```

## URLs

| Service  | URL                              |
|----------|----------------------------------|
| Frontend | http://localhost:3000            |
| Backend  | http://localhost:3001/api/health |
| Postgres | localhost:5432                   |

## Common Commands

```bash
# Start all services (with rebuild)
docker compose up --build

# Start in background
docker compose up -d

# Stop all services
docker compose down

# Stop and remove volumes (wipes database)
docker compose down -v

# View logs
docker compose logs -f

# View logs for a specific service
docker compose logs -f backend
docker compose logs -f frontend
docker compose logs -f postgres
docker compose logs -f migrations

# Rebuild a single service
docker compose up --build backend

# Run the local migration job explicitly
docker compose run --rm migrations
```

## Environment Strategy

Environment variables are separated by responsibility and passed only to the service that needs them:

| File                  | Used by  | Purpose                         |
|-----------------------|----------|---------------------------------|
| `root/.env.frontend`  | frontend | Next.js public vars, API URL    |
| `root/.env.backend`   | backend  | NestJS config, DB connection    |
| `root/.env.database`  | postgres | Postgres init credentials       |

**Committed to git:** Only `.example` files (`*.example`) — never real env files.

**Local only (gitignored):** `.env.frontend`, `.env.backend`, `.env.database`

### Service-level `.env.example` files

Each service also has its own `.env.example` for running **without Docker**:

- `frontend/.env.example` — run `npm run dev` from `frontend/`
- `backend/.env.example` — run `npm run start:dev` from `backend/`

## Services

### postgres
- Image: `postgres:16-alpine`
- Port: `5432`
- Data persisted in Docker volume `postgres_data`
- Init scripts run from `../database/init/`

### backend
- NestJS app running in watch mode (`npm run start:dev`)
- Port: `3001`
- Source code mounted for hot reload
- Waits for postgres to be healthy and for migrations to finish before starting

### migrations
- One-shot backend container that runs `npm run db:migrate`
- Uses the same migration runner as Railway's pre-deploy command
- Creates/reuses `schema_migrations` with filename, checksum, and timestamp
- Local-only baseline mode records already-applied legacy migrations on existing volumes without deleting data

### frontend
- Next.js app running in dev mode (`npm run dev`)
- Port: `3000`
- Source code mounted for hot reload

## Database

Init SQL scripts live in `../backend/database/init/` and run automatically when Postgres starts for the first time.
For existing volumes, new SQL files in `../backend/database/migrations/` are applied by the `migrations` service during `docker compose up --build`.

To reset the database:

```bash
docker compose down -v
docker compose up --build postgres
```
