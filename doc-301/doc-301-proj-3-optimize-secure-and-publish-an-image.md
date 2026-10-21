# Project 03: Optimize, Secure, and Publish an Image — Reference Solution

**Course:** DOC-301 — Docker & Containerization  
**Audience:** Instructors and students reviewing their completed attempt  
**Environment:** Docker Engine / Docker Desktop, POSIX shell examples unless stated otherwise

## What this solution demonstrates

Image hygiene, .dockerignore, least privilege, healthchecks, registry tagging and push. The steps below are one valid implementation, not the only acceptable answer. Verify Docker and Compose versions in your own environment and never paste real secrets into submitted logs.

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

1. Start with the Project 2 source. Create **`.dockerignore`**:

```text
.git
.venv
venv
__pycache__
*.pyc
.env
.env.*
!.env.example
.pytest_cache
.DS_Store
```

2. Replace the Dockerfile with:

```dockerfile
FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
RUN groupadd --system appgroup && useradd --system --gid appgroup --home-dir /app appuser
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY --chown=appuser:appgroup app.py ./
USER appuser
EXPOSE 8000
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)"
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
```

The healthcheck uses Python's standard library, avoiding the need to install `curl`. A nonzero Python exit code marks the check as failed. A non-root user reduces the impact of an application compromise but is not a complete security boundary. For production, also scan images and update dependencies.

3. Build and inspect:

```bash
docker build -t doc301-task-api:1.1 .
docker run -d --name doc301-secure -p 8000:8000 doc301-task-api:1.1
docker exec doc301-secure id
docker inspect --format '{{.Config.User}}' doc301-secure
docker inspect --format '{{json .State.Health}}' doc301-secure
curl -fsS http://localhost:8000/health
```

Wait for the healthcheck interval and verify status becomes `healthy`. Check that `id -u` is not `0`.

4. Publish. Replace `YOUR_DOCKERHUB_USERNAME` with your actual namespace:

```bash
docker login
docker tag doc301-task-api:1.1 YOUR_DOCKERHUB_USERNAME/doc301-task-api:1.1
docker push YOUR_DOCKERHUB_USERNAME/doc301-task-api:1.1
docker rm -f doc301-secure
docker image rm YOUR_DOCKERHUB_USERNAME/doc301-task-api:1.1
docker pull YOUR_DOCKERHUB_USERNAME/doc301-task-api:1.1
docker run -d --name doc301-published -p 8000:8000 YOUR_DOCKERHUB_USERNAME/doc301-task-api:1.1
curl -fsS http://localhost:8000/health
```

`docker login` may use a browser-based flow or a credential helper; never include a password or access token in documentation. Removing the local tag before pulling ensures the registry is actually contacted, though layers may still be cached.

## Troubleshooting

- `denied`: confirm login, namespace and repository permissions.
- `unhealthy`: read `docker inspect` health output and application logs.
- `permission denied`: ensure the non-root user can read copied files and write only to intentionally writable locations.

## Cleanup

`docker rm -f doc301-published`. Leave the pushed version in Docker Hub for reuse.

## Verification checklist

- [ ] Every acceptance criterion in `project.md` has been demonstrated.
- [ ] Commands and observed outputs are included in the project README.
- [ ] No passwords, tokens, or `.env` files have been committed.
- [ ] Cleanup has not unintentionally removed persistent data.

## Instructor notes

Assess observable outcomes, not exact command memorization. Equivalent commands, base images, and file layouts are acceptable when they satisfy the requirements and do not undermine safety. Ask the student to explain *why* their configuration works and how they verified it.
