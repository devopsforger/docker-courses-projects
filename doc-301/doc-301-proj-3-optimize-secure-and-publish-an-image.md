# Project 03: Optimize, Secure, and Publish an Image — Detailed Reference Solution

**Course:** DOC-301 — Docker & Containerization  
**Source verification:** Paired against uploaded Project 03 requirements and uploaded original Project 03 reference solution.  
**Scope:** Beginner-friendly Bash/POSIX-shell walkthrough; commands are illustrative until run on a Docker host.

## What you are building

The API works locally. Prepare a safer distributable image and publish a versioned release to Docker Hub.

## Requirement-by-requirement coverage

| # | Published requirement | Where it is demonstrated |
|---|---|---|
| 1 | Improve the Project 2 Dockerfile using a small maintained base image and effective build caching. | Guided implementation / investigation below; see verification checklist |
| 2 | Add `.dockerignore` and run the application as a non-root user. | Guided implementation / investigation below; see verification checklist |
| 3 | Add a Docker `HEALTHCHECK` for `/health`. | Guided implementation / investigation below; see verification checklist |
| 4 | Build, inspect, and verify the image, including its runtime user and health status. | Guided implementation / investigation below; see verification checklist |
| 5 | Tag the image with your own Docker Hub namespace and push it. | Guided implementation / investigation below; see verification checklist |
| 6 | Pull the published image and run it to confirm the release works. | Guided implementation / investigation below; see verification checklist |

## Guided implementation and explanations

### Step 1: Measure the Project 2 image

```bash
docker image ls doc301-task-api
docker history doc301-task-api:1.0
docker image inspect doc301-task-api:1.0 --format '{{.Size}}'
```

Record the original size in bytes and its layer history. `docker history` is not a security scan; it helps identify build steps and large layers. Image sizes can differ between architectures.

### Step 2: Reduce the build context

Create `.dockerignore` beside the Dockerfile:

```dockerignore
.git
.venv
venv
__pycache__
*.pyc
.pytest_cache
.env
.env.*
!.env.example
.DS_Store
```

Docker applies these patterns to files sent in the build context. They keep source-control history, virtual environments, caches, and local secrets out of the context. This does not erase secrets from any image built earlier, so never put them in the build context in the first place.

### Step 3: Use the improved Dockerfile

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

`ENV` avoids Python bytecode files and buffers less log output. `groupadd` and `useradd` create a dedicated non-root identity. `COPY --chown` gives ownership of the source file to that identity. `USER` makes subsequent runtime execution non-root. `HEALTHCHECK` periodically calls the HTTP endpoint using Python's standard library; connection failures or non-2xx responses raise an error, so the check fails. `--start-period` provides startup grace time; `--retries` controls how many consecutive failures lead to `unhealthy`. Non-root operation reduces risk but is not a complete sandbox.

### Step 4: Build and verify security, size, and health

```bash
docker build -t doc301-task-api:1.1 .
docker image inspect doc301-task-api:1.1 --format '{{.Size}}'
docker history doc301-task-api:1.1
docker run -d --name doc301-secure -p 8000:8000 doc301-task-api:1.1
docker exec doc301-secure id -u
docker inspect doc301-secure --format 'User={{.Config.User}} Healthcheck={{json .Config.Healthcheck}}'
docker inspect doc301-secure --format '{{json .State.Health}}'
curl -fsS http://localhost:8000/health
```

Wait at least one healthcheck interval, then inspect again until the state is `healthy`. The UID must not be `0`. Compare the recorded sizes and histories. Optimization does not guarantee a smaller result in every environment; explain the measured difference rather than claiming one.

### Step 5: Publish and independently pull the release

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

Replace the placeholder namespace with your own. `tag` creates a registry-qualified reference; `push` uploads it. Removing the local registry tag before `pull` helps demonstrate a registry retrieval, though cached layers may be reused. Never put tokens in the Dockerfile or command transcript. Include the Docker Hub repository URL and version tag in your README.

### Cleanup

```bash
docker rm -f doc301-published
```

Leave the versioned image available for Project 5. If Docker Hub rejects the push, confirm the namespace, authentication, and repository permissions.

## Acceptance criteria to verify

- [ ] Container runs as a non-root UID.
- [ ] `docker inspect` reports a configured healthcheck and `healthy` status.
- [ ] Image can be pulled from Docker Hub and `/health` responds.
- [ ] Build context excludes `.git`, virtual environments, caches, and secrets.

## Constraints from the project

- Never put registry credentials in a Dockerfile, command transcript, or repository.
- Use a versioned tag; avoid relying solely on `latest`.
- A healthcheck must fail on non-2xx HTTP responses or connection errors.

## Required deliverables

- Dockerfile, `.dockerignore`, image tag, Docker Hub repository URL, and verification transcript.

## Original reference solution, retained for comparison

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
