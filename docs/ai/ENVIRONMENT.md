# ENVIRONMENT

## Purpose

How to run, configure, and deploy the Klyro stack: Docker, environment variables, and local setup.

## When to read

Before touching Docker, env vars, setup, or deployment — and when onboarding.

## Keep updated

When compose files, env vars, setup, or deployment steps change.

## Services & containers (`docker-compose.yml`)

| Service | Image / build | Ports | Purpose |
| --- | --- | --- | --- |
| `postgres` | `postgres:16-alpine` | `5432:5432` | Database; init + seed SQL mounted into `/docker-entrypoint-initdb.d`; healthcheck via `pg_isready` |
| `backend` | build `../backend/Dockerfile` | `3001:3001` | NestJS API (`npm run start:dev`); depends on healthy postgres |
| `frontend` | build `../frontend/Dockerfile` | (see compose) | Next.js app |

All on `klyro-network`. `postgres_data` volume persists DB data. Backend uses polling watch flags for Docker file-watching.

## First-boot SQL mount order

`000-create-database` → `001-enums` → `002-tables` → `003-scheduling-functions` → seeds `001`→`005`. Order matters (enums before tables before functions before seeds).

## Environment variables

> Provided via `env_file`: `.env.database`, `.env.backend`, `.env.frontend`. Never commit real secrets. Fill the real variable names/usages below.

| Variable | Used by | Required | Notes |
| --- | --- | --- | --- |
| `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` | postgres (`.env.database`) | yes | DB credentials (referenced by healthcheck) |
| `FRONTEND_URL` | backend | yes | CORS origin (default `http://localhost:3000`) |
| `DATABASE_URL` / DB connection vars | backend (`.env.backend`) | yes | TypeORM connection |
| _add backend JWT/Firebase/WhatsApp/etc._ | backend | varies | document as discovered |
| _add frontend `NEXT_PUBLIC_*` / API base URL_ | frontend (`.env.frontend`) | varies | document as discovered |

## Local setup

1. Create `.env.database`, `.env.backend`, `.env.frontend` (see variables above).
2. From `root/`: `docker compose up` (postgres initializes schema + seeds on first boot).
3. Backend on `:3001` (`/api`, Swagger at `/api/docs`); frontend on `:3000`.

## Deployment

- _Document the real deployment target/process here._

> Must reflect the real current infrastructure, not assumptions.
