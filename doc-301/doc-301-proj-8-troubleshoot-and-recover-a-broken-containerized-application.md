# Project 08: Troubleshoot and Recover a Broken Containerized Application — Reference Solution

**Course:** DOC-301 — Docker & Containerization  
**Audience:** Instructors and students reviewing their completed attempt  
**Environment:** Docker Engine / Docker Desktop, POSIX shell examples unless stated otherwise

## What this solution demonstrates

Logs, inspect, exec, configuration diagnosis, dns, health, root cause and recovery. The steps below are one valid implementation, not the only acceptable answer. Verify Docker and Compose versions in your own environment and never paste real secrets into submitted logs.

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
## Instructor setup (do not reveal before assessment)

Start with the functioning Project 6 app, Dockerfile and Compose file. Create a task named `existing-record` and verify it appears in `GET /tasks`. Keep the database volume. Save a working copy of `compose.yaml` as `compose.reference.yaml` outside the student's starter folder.

For the exercise, deliberately introduce **four independent faults** in the Compose configuration:

1. **Incorrect API port mapping:** change `"8000:8000"` to `"8000:8001"`.
2. **Wrong database hostname:** change the `DATABASE_URL` host from `db` to `database` (without renaming the actual `db` service).
3. **Invalid database password:** replace the password in `DATABASE_URL` with `wrongpassword` while leaving the database's initialized password unchanged.
4. **Broken DB healthcheck:** change the `pg_isready` command to `pg_isready -h does-not-exist -U taskuser -d tasks`.

**Important sequencing:** With the broken database healthcheck, `depends_on: condition: service_healthy` prevents API startup. This is intentional. Once that fault is corrected, the hostname and password faults will become visible. The wrong port mapping remains independently observable. Students must not remove the volume or replace the database to pass the exercise.

## Student investigation walkthrough

1. Record the initial symptoms and state:

```bash
docker compose config --quiet
docker compose up -d --build || true
docker compose ps -a
docker compose logs --tail=100 db api
```

2. Inspect database health:

```bash
DB_CID=$(docker compose ps -q db)
docker inspect "$DB_CID" --format '{{json .State.Health}}'
```

The healthcheck fails because `does-not-exist` is not a resolvable DB host. Fix it to:

```yaml
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U taskuser -d tasks"]
      interval: 5s
      timeout: 3s
      retries: 10
```

Recreate services: `docker compose up -d --force-recreate`. Inspect logs again.

3. Identify the incorrect API DB hostname in `DATABASE_URL` and restore `@db:5432/tasks`. Compose's service name `db` is the DNS name. Validate the service network:

```bash
docker compose ps
docker network ls
docker compose exec db getent hosts db
```

`getent` is normally available in the PostgreSQL Debian-based image; if unavailable, use `docker network inspect` on the Compose-created network.

4. Fix the bad password. The actual database password is the one used when its persistent volume was initialized. Restore the correct password in the API's connection string. For the reference setup, use the value from the instructor's `.env` file. Never paste secrets into an incident report. Note that a PostgreSQL password error is not equivalent to a DNS failure; inspect error messages to distinguish them.

5. Fix the published port mapping to `"8000:8000"`. The API listens on 8000 inside the container, so host port 8000 must map to container port 8000. Verify with `docker compose port api 8000`.

6. Recreate and test:

```bash
docker compose up -d --build --force-recreate
docker compose ps
curl -fsS http://localhost:8000/health
curl -fsS http://localhost:8000/tasks
curl -fsS -X POST http://localhost:8000/tasks \
  -H 'Content-Type: application/json' -d '{"title":"recovered-service"}'
curl -fsS http://localhost:8000/tasks
```

Expected: `existing-record` is still present, the new task is created, and both services run. A healthy database container is not sufficient evidence that the API has correct credentials; the API task endpoints verify end-to-end behavior.

## Incident report template

```markdown
# DOC-301 Incident Report
- Impact and observed symptoms:
- Timeline and commands used:
- Root cause 1 (evidence, fix, verification):
- Root cause 2 (evidence, fix, verification):
- Root cause 3 (evidence, fix, verification):
- Root cause 4 (evidence, fix, verification):
- Evidence existing data was preserved:
- Prevention and monitoring improvements:
```

## Troubleshooting notes

- Fixing the healthcheck may reveal previously hidden API errors. Re-run diagnostics after each change.
- Avoid deleting the database volume: doing so may appear to fix mismatched credentials but destroys stored records.
- `docker compose exec api ...` cannot run if the API service has not started; use `logs` and `inspect` first.

## Cleanup

`docker compose down` preserves the database volume. Archive the corrected Compose configuration and redacted evidence. Delete the volume only after the instructor confirms data is no longer needed.

## Verification checklist

- [ ] Every acceptance criterion in `project.md` has been demonstrated.
- [ ] Commands and observed outputs are included in the project README.
- [ ] No passwords, tokens, or `.env` files have been committed.
- [ ] Cleanup has not unintentionally removed persistent data.

## Instructor notes

Assess observable outcomes, not exact command memorization. Equivalent commands, base images, and file layouts are acceptable when they satisfy the requirements and do not undermine safety. Ask the student to explain *why* their configuration works and how they verified it.
