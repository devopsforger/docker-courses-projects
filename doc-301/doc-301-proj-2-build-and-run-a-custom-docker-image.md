# Project 02: Build and Run a Custom Docker Image — Reference Solution

**Course:** DOC-301 — Docker & Containerization  
**Audience:** Instructors and students reviewing their completed attempt  
**Environment:** Docker Engine / Docker Desktop, POSIX shell examples unless stated otherwise

## What this solution demonstrates

Dockerfile, build context, layers, image tags, cmd and port publishing. The steps below are one valid implementation, not the only acceptable answer. Verify Docker and Compose versions in your own environment and never paste real secrets into submitted logs.

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

1. Create a directory containing the supplied `app.py` and `requirements.txt`.
2. Create **`Dockerfile`**:

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py ./
EXPOSE 8000
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
```

`COPY requirements.txt` before application source allows the dependency-install layer to be reused when only code changes. `EXPOSE` documents a port but does not publish it. `0.0.0.0` is required to listen on the container's network interface.

3. Build and run:

```bash
docker build -t doc301-task-api:1.0 .
docker run -d --name doc301-api -p 8000:8000 doc301-task-api:1.0
```

4. Verify:

```bash
curl -fsS http://localhost:8000/health
curl -fsS http://localhost:8000/tasks
docker logs doc301-api
docker image inspect doc301-task-api:1.0 --format '{{.Config.Cmd}}'
```

Expected JSON: `{"status":"ok"}` and `[]`. `POST /tasks` returns HTTP 503 until the database is configured; this is expected in this project.

## Troubleshooting

- Connection refused: inspect logs and confirm `-p 8000:8000` and `--host 0.0.0.0`.
- Import error: confirm files are named `app.py` and `requirements.txt` and the build context is the current directory.
- Dependency installation error: confirm Internet access and pinned package versions; update pins only after testing compatibility.

## Cleanup

```bash
docker rm -f doc301-api
```

Keep the image for Project 3.

## Verification checklist

- [ ] Every acceptance criterion in `project.md` has been demonstrated.
- [ ] Commands and observed outputs are included in the project README.
- [ ] No passwords, tokens, or `.env` files have been committed.
- [ ] Cleanup has not unintentionally removed persistent data.

## Instructor notes

Assess observable outcomes, not exact command memorization. Equivalent commands, base images, and file layouts are acceptable when they satisfy the requirements and do not undermine safety. Ask the student to explain *why* their configuration works and how they verified it.
