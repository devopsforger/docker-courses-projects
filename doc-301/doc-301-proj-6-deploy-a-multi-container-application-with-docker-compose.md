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
