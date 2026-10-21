# Project 05: Connect Containers Using Docker Networks — Reference Solution

**Course:** DOC-301 — Docker & Containerization  
**Audience:** Instructors and students reviewing their completed attempt  
**Environment:** Docker Engine / Docker Desktop, POSIX shell examples unless stated otherwise

## What this solution demonstrates

User-defined bridge networking, service-name dns, internal ports and api/database integration. The steps below are one valid implementation, not the only acceptable answer. Verify Docker and Compose versions in your own environment and never paste real secrets into submitted logs.

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

Use the improved image from Project 3, built locally as `doc301-task-api:1.1`. This exercise uses a fresh volume named `doc301-net-pgdata` to avoid collisions with Project 4.

1. Create a private network and a volume:

```bash
docker network create doc301-net
docker volume create doc301-net-pgdata
read -rsp 'Local database password: ' POSTGRES_PASSWORD; echo
export POSTGRES_PASSWORD
```

2. Start PostgreSQL without publishing port 5432:

```bash
docker run -d --name doc301-db --network doc301-net \
  -e POSTGRES_USER=taskuser -e POSTGRES_DB=tasks \
  -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
  -v doc301-net-pgdata:/var/lib/postgresql/data postgres:17
until docker exec doc301-db pg_isready -U taskuser -d tasks; do sleep 2; done
```

3. Start the API on the same network. Use URL-safe characters in the password, or percent-encode special URL characters in `DATABASE_URL`. For this learning exercise, choose a strong alphanumeric password.

```bash
docker run -d --name doc301-api --network doc301-net \
  -p 8000:8000 \
  -e "DATABASE_URL=postgresql://taskuser:${POSTGRES_PASSWORD}@doc301-db:5432/tasks" \
  doc301-task-api:1.1
```

4. Verify database-backed requests:

```bash
curl -fsS http://localhost:8000/health
curl -fsS -X POST http://localhost:8000/tasks \
  -H 'Content-Type: application/json' \
  -d '{"title":"Learn Docker networking"}'
curl -fsS http://localhost:8000/tasks
docker network inspect doc301-net
docker port doc301-db
```

Expected: POST returns HTTP 201 with a generated ID; GET returns that task. `docker port doc301-db` should display no published port. DNS is resolved using `doc301-db` on the user-defined bridge. For a DNS check without extra utilities in the API image, run:

```bash
docker exec doc301-api python -c "import socket; print(socket.gethostbyname('doc301-db'))"
```

The resolved IP is ephemeral and must not be hard-coded. If the API exits before PostgreSQL is ready, inspect its logs and recreate it after readiness; Project 6 improves startup orchestration.

## Troubleshooting

- `could not translate host name`: inspect network membership and spelling of `doc301-db`.
- Connection refused: confirm database readiness and internal port 5432.
- Authentication failed: confirm the database's initialized user/password, not merely new environment variables.

## Cleanup

```bash
docker rm -f doc301-api doc301-db
docker network rm doc301-net
unset POSTGRES_PASSWORD
```

Keep `doc301-net-pgdata` unless you intentionally want to erase the database.

## Verification checklist

- [ ] Every acceptance criterion in `project.md` has been demonstrated.
- [ ] Commands and observed outputs are included in the project README.
- [ ] No passwords, tokens, or `.env` files have been committed.
- [ ] Cleanup has not unintentionally removed persistent data.

## Instructor notes

Assess observable outcomes, not exact command memorization. Equivalent commands, base images, and file layouts are acceptable when they satisfy the requirements and do not undermine safety. Ask the student to explain *why* their configuration works and how they verified it.
