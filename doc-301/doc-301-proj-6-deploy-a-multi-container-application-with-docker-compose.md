# Project 06: Deploy a Multi-Container Application with Docker Compose — Updated Reference Solution

**Course:** DOC-301 — Docker & Containerization  
**Application source:** [TaskForge](https://github.com/devopsforger/taskforge)  

## Starter application

Use the existing [TaskForge starter repository](https://github.com/devopsforger/taskforge), specifically [`backend/main.py`](https://github.com/devopsforger/taskforge/blob/master/backend/main.py) and [`backend/requirements.txt`](https://github.com/devopsforger/taskforge/blob/master/backend/requirements.txt). **Do not copy or rewrite the Python application source into this solution.** The Docker learning objectives are about packaging and operating the supplied application.

TaskForge differs from the original DOC-301 sample: it uses `main.py` (not `app.py`), SQLAlchemy, and a **mandatory** `DATABASE_URL`. It cannot serve `/health` or `/tasks` without a reachable database. `/health` checks database connectivity, and task records include `done`. Where the original project asks for a database-free API, this guide explains the necessary adaptation rather than pretending the starter supports it.

Clone once and work from the repository root:

```bash
git clone https://github.com/devopsforger/taskforge.git
cd taskforge
```

All examples use a disposable local password. Never commit `.env` or paste real credentials into reports. Commands are reference examples, not runtime-tested in this environment.
## Objective

Use Docker Compose to build the TaskForge backend and run it alongside PostgreSQL. The upstream starter has three services (frontend, API, database), but this DOC-301 exercise intentionally defines only **two**: `api` and `db`. The API is built from `./backend`; do not duplicate Python files or use `build: .`.

## Step 1: Create `.env.example` and `.gitignore`

```dotenv
POSTGRES_PASSWORD=REPLACE_WITH_A_DISPOSABLE_ALPHANUMERIC_PASSWORD
```

```gitignore
.env
```

Copy `.env.example` to `.env`, choose a disposable alphanumeric password, and never commit `.env`. Special characters in a database URL must be URL-encoded.

## Step 2: Create a course-specific `compose.doc301.yaml` at the repository root

```yaml
services:
  db:
    image: postgres:18.6-alpine
    environment:
      POSTGRES_USER: taskforge
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?Set POSTGRES_PASSWORD in .env}
      POSTGRES_DB: taskforge
    volumes:
      - pgdata:/var/lib/postgresql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U taskforge -d taskforge"]
      interval: 5s
      timeout: 3s
      retries: 12
  api:
    build:
      context: ./backend
      dockerfile: Dockerfile.doc301.secure
    environment:
      DATABASE_URL: postgresql+psycopg2://taskforge:${POSTGRES_PASSWORD:?Set POSTGRES_PASSWORD in .env}@db:5432/taskforge
    ports:
      - "8000:8000"
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped
volumes:
  pgdata:
```

The named volume survives container recreation. `depends_on: condition: service_healthy` waits for the database healthcheck before starting the API; it does not guarantee the database remains available forever. Only the API has a host port. Compose creates a private network, and the hostname `db` resolves to the database service. PostgreSQL 18's data directory mount is `/var/lib/postgresql`.

If you have not completed Project 3, create `backend/Dockerfile.doc301.secure` using that solution first. Do not change the TaskForge application code.

## Step 3: Validate and start

```bash
docker compose -f compose.doc301.yaml config --quiet
docker compose -f compose.doc301.yaml up -d --build
docker compose -f compose.doc301.yaml ps
docker compose -f compose.doc301.yaml logs --tail=50 db api
```

The `-f` flag selects this course's two-service file instead of TaskForge's existing three-service `compose.yaml`. `config --quiet` validates interpolation without printing passwords. `up -d --build` rebuilds the API and starts in the background.

## Step 4: Verify requests and persistence

```bash
curl -fsS http://localhost:8000/health
curl -i -X POST http://localhost:8000/tasks -H 'Content-Type: application/json' -d '{"title":"Compose task"}'
curl -fsS http://localhost:8000/tasks
docker compose -f compose.doc301.yaml port api 8000
docker compose -f compose.doc301.yaml down
docker compose -f compose.doc301.yaml up -d
curl -fsS http://localhost:8000/tasks
```

The previously created task should remain. `down` removes containers and networks, but **not** named volumes by default. `down -v` would delete the database volume and invalidate the persistence test. Do not publish PostgreSQL's port.

## Step 5: Demonstrate lifecycle and submit evidence

```bash
docker compose -f compose.doc301.yaml stop
docker compose -f compose.doc301.yaml start
docker compose -f compose.doc301.yaml ps
docker compose -f compose.doc301.yaml down
```

Submit the Compose file, Dockerfile, `.env.example`, README, redacted logs, and HTTP outputs. Explain the build context, service DNS, health-gated startup, and persistence. Preserve the configuration for Projects 7 and 8.
