# Project 06: Deploy a Multi-Container Application with Docker Compose — Detailed Reference Solution

**Course:** DOC-301 — Docker & Containerization  
**Source verification:** Paired against uploaded Project 06 requirements and uploaded original Project 06 reference solution.  
**Scope:** Beginner-friendly Bash/POSIX-shell walkthrough; commands are illustrative until run on a Docker host.

## What you are building

Your team is tired of copying long `docker run` commands. Turn the API/database deployment into a repeatable Compose application.

## Requirement-by-requirement coverage

| # | Published requirement | Where it is demonstrated |
|---|---|---|
| 1 | Write `compose.yaml` defining `api` and `db` services. | Guided implementation / investigation below; see verification checklist |
| 2 | Build the API image from the supplied application and improved Dockerfile. | Guided implementation / investigation below; see verification checklist |
| 3 | Give PostgreSQL a named volume and a database healthcheck. | Guided implementation / investigation below; see verification checklist |
| 4 | Configure the API to wait for the database to become healthy using Compose dependencies. | Guided implementation / investigation below; see verification checklist |
| 5 | Publish only the API port to the host. | Guided implementation / investigation below; see verification checklist |
| 6 | Create and list tasks, restart services, and verify persistence. | Guided implementation / investigation below; see verification checklist |
| 7 | Demonstrate `docker compose up`, `ps`, `logs`, and `down`. | Guided implementation / investigation below; see verification checklist |

## Guided implementation and explanations

### Step 1: Assemble the Compose project

Place the supplied `app.py`, `requirements.txt`, the improved Project 3 `Dockerfile`, and `.dockerignore` in one directory. Create `compose.yaml`:

```yaml
services:
  db:
    image: postgres:17
    environment:
      POSTGRES_USER: taskuser
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?Set POSTGRES_PASSWORD in .env}
      POSTGRES_DB: tasks
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U taskuser -d tasks"]
      interval: 5s
      timeout: 3s
      retries: 10
  api:
    build: .
    environment:
      DATABASE_URL: postgresql://taskuser:${POSTGRES_PASSWORD:?Set POSTGRES_PASSWORD in .env}@db:5432/tasks
    ports:
      - "8000:8000"
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped
volumes:
  pgdata:
```

`services` defines the two containers. `image` selects PostgreSQL 17; `build: .` builds the API from the current directory. `environment` passes settings at runtime. The `${NAME:?message}` expression stops Compose configuration when the variable is missing. `volumes` attaches persistent storage; the top-level declaration tells Compose to manage it. The database healthcheck runs `pg_isready` inside the database container. `depends_on` with `service_healthy` waits for a passing database healthcheck before creating the API. `ports` publishes only the API. Compose automatically creates a project network and resolves the service name `db` through DNS.

### Step 2: Supply a local-only password

Create `.env.example`:

```dotenv
POSTGRES_PASSWORD=REPLACE_WITH_A_STRONG_ALPHANUMERIC_PASSWORD
```

Copy it to `.env` and replace the example value. Add `.env` to `.gitignore` and `.dockerignore`. Use an alphanumeric training password to avoid URL encoding problems. A Compose `.env` file is for variable interpolation, not production-grade secret management; environment values can be inspected by administrators with Docker access.

### Step 3: Validate and deploy

```bash
docker compose version
docker compose config --quiet
docker compose up -d --build
docker compose ps
docker compose logs --tail=50 db api
```

`config --quiet` checks the Compose file and required interpolation variables without printing the expanded configuration (which could expose the password). `up -d --build` builds the API and starts services in the background. `ps` shows service state; `logs` helps confirm readiness. Do not submit unredacted logs containing secrets.

### Step 4: Create data, remove containers, and restore

```bash
curl -fsS http://localhost:8000/health
curl -i -X POST http://localhost:8000/tasks -H 'Content-Type: application/json' -d '{"title":"Compose task"}'
curl -fsS http://localhost:8000/tasks
docker compose port api 8000
docker compose down
docker compose up -d
curl -fsS http://localhost:8000/tasks
docker compose ps
```

The task should remain after `down` and `up -d`, because `down` removes containers and the Compose network but **not** the named volume by default. `docker compose port api 8000` reports the API's published host port. The `db` service must have no `ports:` entry. Never use `docker compose down -v` during persistence verification because `-v` removes named volumes declared by the Compose project.

### Step 5: Demonstrate lifecycle and cleanup

```bash
docker compose stop
docker compose start
docker compose ps
docker compose down
```

`stop` halts existing service containers without deleting them; `start` restarts those containers. `down` removes containers and networks while preserving the named database volume. Include the Compose file, `.env.example`, Dockerfile, README, and redacted verification outputs in your submission.

## Acceptance criteria to verify

- [ ] `docker compose config` validates the configuration.
- [ ] API requests succeed after database startup.
- [ ] Database records survive `docker compose down` followed by `up -d`.
- [ ] The database has no published host port.

## Constraints from the project

- Do not commit `.env` or credentials.
- Use Compose service names for inter-service DNS.
- Do not publish the database port.
- Do not run `docker compose down -v` during persistence verification.

## Required deliverables

- `compose.yaml`, Dockerfile, `.env.example`, README, and terminal/API verification output.

## Original reference solution, retained for comparison

# Project 06: Deploy a Multi-Container Application with Docker Compose — Reference Solution

**Course:** DOC-301 — Docker & Containerization  
**Audience:** Instructors and students reviewing their completed attempt  
**Environment:** Docker Engine / Docker Desktop, POSIX shell examples unless stated otherwise

## What this solution demonstrates

Compose services, dependency health, named volumes, environment injection and repeatable deployments. The steps below are one valid implementation, not the only acceptable answer. Verify Docker and Compose versions in your own environment and never paste real secrets into submitted logs.

# Shared Task API reference application

Projects 2–8 use the same small Python/FastAPI application. The instructor supplies the following files as starter material; students are not assessed on writing Python. This reference implementation is reproduced here so the solutions can be followed independently. Use Python 3.12 and the dependency versions below as a tested baseline; update and re-test dependency versions regularly.

**`requirements.txt`**

```text
fastapi==0.115.12
uvicorn==0.34.2
psycopg[binary]==3.2.6
```

**`app.py`**

```python
import os
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
import psycopg

DATABASE_URL = os.getenv("DATABASE_URL")

@asynccontextmanager
async def lifespan(app: FastAPI):
    if DATABASE_URL:
        with psycopg.connect(DATABASE_URL) as conn:
            conn.execute("CREATE TABLE IF NOT EXISTS tasks (id SERIAL PRIMARY KEY, title TEXT NOT NULL)")
            conn.commit()
    yield

app = FastAPI(lifespan=lifespan)

class TaskIn(BaseModel):
    title: str = Field(min_length=1, max_length=200)

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/tasks")
def list_tasks():
    if not DATABASE_URL:
        return []
    with psycopg.connect(DATABASE_URL) as conn:
        rows = conn.execute("SELECT id, title FROM tasks ORDER BY id").fetchall()
    return [{"id": r[0], "title": r[1]} for r in rows]

@app.post("/tasks", status_code=201)
def add_task(task: TaskIn):
    if not DATABASE_URL:
        raise HTTPException(503, "Database is not configured")
    with psycopg.connect(DATABASE_URL) as conn:
        row = conn.execute("INSERT INTO tasks (title) VALUES (%s) RETURNING id", (task.title,)).fetchone()
        conn.commit()
    return {"id": row[0], "title": task.title}
```

**Notes:** `/health` reports process health, not database readiness. For Projects 5–8, successful `GET /tasks` is the database-connectivity check. On startup, a configured but unavailable database causes the API to exit; Compose will handle ordering and restart behavior as described later. `DATABASE_URL` must never be hard-coded into an image. The `POST /tasks` endpoint is available only when PostgreSQL is configured.
## Walkthrough

1. Create a directory with the shared `app.py`, `requirements.txt`, the improved Dockerfile and `.dockerignore` from Project 3.
2. Add a `compose.yaml`:

**`compose.yaml`**

```yaml
services:
  db:
    image: postgres:17
    environment:
      POSTGRES_USER: taskuser
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?Set POSTGRES_PASSWORD in .env}
      POSTGRES_DB: tasks
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U taskuser -d tasks"]
      interval: 5s
      timeout: 3s
      retries: 10

  api:
    build: .
    environment:
      DATABASE_URL: postgresql://taskuser:${POSTGRES_PASSWORD:?Set POSTGRES_PASSWORD in .env}@db:5432/tasks
    ports:
      - "8000:8000"
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped

volumes:
  pgdata:
```

3. Add **`.env.example`** containing `POSTGRES_PASSWORD=REPLACE_WITH_A_STRONG_ALPHANUMERIC_PASSWORD`. Copy it to `.env`, replace the value, and ensure `.env` is in `.gitignore` and `.dockerignore`. For this beginner example, use a strong alphanumeric value so no URL encoding is needed. Note: Compose interpolation places the password into service environment variables, visible to users with Docker administrative access. For production use, adopt a secret-management solution.

4. Validate, build, start and inspect:

```bash
docker compose config --quiet
docker compose up -d --build
docker compose ps
docker compose logs --tail=50 db api
```

5. Verify application and persistence:

```bash
curl -fsS -X POST http://localhost:8000/tasks \
  -H 'Content-Type: application/json' -d '{"title":"Compose task"}'
curl -fsS http://localhost:8000/tasks
docker compose down
docker compose up -d
curl -fsS http://localhost:8000/tasks
```

Expected: the task persists because `down` removes containers and the network, **not** named volumes by default. The `db` service is available to `api` by DNS name `db` on Compose's default network. `depends_on` with `service_healthy` delays API creation until the database healthcheck passes; it does not guarantee database availability forever.

6. Inspect the published ports:

```bash
docker compose ps
docker compose port api 8000
```

No `ports:` declaration should exist for `db`.

## Troubleshooting

- Missing variable: populate `.env` before running `docker compose config`.
- API exits: inspect logs, DB credentials, and connection string.
- Password change not applied: PostgreSQL retains its original credentials in the existing volume; do not delete data to hide this mismatch.
- Port 8000 in use: change the host side of the mapping, and update curl URLs.

## Cleanup

`docker compose down` (preserves data). **Never run `docker compose down -v` unless intentionally deleting the project's database.**

## Verification checklist

- [ ] Every acceptance criterion in `project.md` has been demonstrated.
- [ ] Commands and observed outputs are included in the project README.
- [ ] No passwords, tokens, or `.env` files have been committed.
- [ ] Cleanup has not unintentionally removed persistent data.

## Instructor notes

Assess observable outcomes, not exact command memorization. Equivalent commands, base images, and file layouts are acceptable when they satisfy the requirements and do not undermine safety. Ask the student to explain *why* their configuration works and how they verified it.
