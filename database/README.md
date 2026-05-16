# Database

PostgreSQL database configuration and scripts for Klyro Platform.

## Structure

```
database/
├── init/         # SQL scripts that run on first Postgres start
├── seeds/        # Development/test seed data
└── migrations/   # Schema migration files (managed by backend ORM)
```

## Init Scripts

Scripts in `init/` are mounted into Docker at `/docker-entrypoint-initdb.d/` and run automatically when the Postgres container starts for the first time (i.e., when the volume is empty).

They run in alphabetical order:
- `001-init.sql` — Enables extensions like uuid-ossp

## Running from root

```bash
cd root
docker compose up postgres
```
