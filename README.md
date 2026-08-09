# Medusa Store — Local Development Environment

A learning project exploring [Medusa](https://medusajs.com/), an open-source headless commerce platform, running locally with Docker-managed backing services.

## Overview

This project sets up the infrastructure needed to run a Medusa store locally: a PostgreSQL database for persistent storage and a Redis instance for caching and event handling. The Medusa server itself runs on the host, connecting to these containerized services.

## Tech Stack

- **Medusa** — headless commerce engine (API + admin)
- **PostgreSQL 15** (Alpine) — primary datastore
- **Redis 7** (Alpine) — caching / event bus
- **Docker Compose** — service orchestration

## Architecture

```
┌─────────────────┐
│  Medusa Server   │  (runs on host)
└────────┬─────────┘
         │
   ┌─────┴──────┐
   │            │
┌──▼───┐    ┌───▼───┐
│Postgres│  │ Redis │
│ :5432  │  │ :6379 │
└────────┘  └───────┘
   medusa-net (bridge)
```

## Prerequisites

- Docker & Docker Compose
- Node.js (LTS) and npm/yarn
- Medusa CLI (`npm install -g @medusajs/medusa-cli`)

## Getting Started

### 1. Start backing services

```bash
docker-compose up -d
```

This brings up:
- `medusa-postgres` — Postgres 15, exposed on `5432`, database `medusa-store`
- `medusa-redis` — Redis 7, exposed on `6379`

Postgres includes a health check (`pg_isready`) so dependent services can wait for it to be ready before connecting.

### 2. Verify containers are running

```bash
docker-compose ps
```

### 3. Configure Medusa

Point your Medusa `.env` at the containerized services, e.g.:

```env
DATABASE_URL=postgres://postgres:secure_password_123@localhost:5432/medusa-store
REDIS_URL=redis://localhost:6379
```

> ⚠️ The password in `docker-compose.yml` is a local development default — replace it before using this setup anywhere beyond your own machine.

### 4. Run Medusa

```bash
medusa develop
```

## Verifying the Setup

- **Server running** — confirmed the Medusa server starts and serves the admin/store APIs locally.
- **API probe** — checked core API endpoints to confirm the server responds correctly against the Postgres/Redis backend.

## Data Persistence

Both services use named Docker volumes so data survives container restarts:

| Volume | Service | Purpose |
|---|---|---|
| `postgres-data` | Postgres | Store/product/order data |
| `redis-data` | Redis | Cache and event queue state |

## Notes / Learnings

- Postgres and Redis are isolated on a dedicated bridge network (`medusa-net`) so containers can reach each other by service name.
- The Postgres health check prevents race conditions where the app tries to connect before the database is ready.
- Credentials in this compose file are placeholders for local development only and should be replaced with secrets management for any shared or production environment.

## Project Status

Learning project — used to understand how Medusa's backend services fit together and how to containerize the supporting infrastructure with Docker Compose.

## License

For personal/educational use.