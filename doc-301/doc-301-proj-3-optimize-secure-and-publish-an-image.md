# Project 03: Optimize, Secure, and Publish an Image — Updated Reference Solution

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
## Step 1: Record the original image

```bash
docker image inspect doc301-task-api:1.0 --format '{{.Size}}'
docker history doc301-task-api:1.0
```

Record image size in bytes and the layer history. The size is an observation, not a guaranteed optimization target.

## Step 2: Create `backend/.dockerignore`

```dockerignore
.git
.venv
venv
__pycache__
*.pyc
.pytest_cache
.env
.env.*
.DS_Store
```

This excludes unnecessary files from the `backend` build context. It does not remove data from images already built.

## Step 3: Create `backend/Dockerfile.doc301.secure`

```dockerfile
FROM python:3.13-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
RUN groupadd --system appgroup && useradd --system --gid appgroup appuser
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY --chown=appuser:appgroup main.py ./
USER appuser
EXPOSE 8000
HEALTHCHECK --interval=15s --timeout=3s --start-period=20s --retries=3 CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)"
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

The `USER` instruction prevents the application from running as root. `--chown` sets source-file ownership. The healthcheck makes an HTTP request and fails on connection or HTTP errors. TaskForge's `/health` also queries PostgreSQL, so a missing database causes an unhealthy state. Non-root execution and healthchecks improve operational safety but do not replace vulnerability scanning or secrets management.

## Step 4: Build, run with database, and inspect

```bash
docker build -f backend/Dockerfile.doc301.secure -t doc301-task-api:1.1 backend
docker image inspect doc301-task-api:1.1 --format '{{.Size}}'
docker history doc301-task-api:1.1
```

For runtime checks, **first start the PostgreSQL container and Docker network from Project 2**, then run:

```bash
docker run -d --name doc301-secure --network doc301-net -p 8000:8000 \
  -e "DATABASE_URL=postgresql+psycopg2://taskforge:${POSTGRES_PASSWORD}@doc301-db:5432/taskforge" \
  doc301-task-api:1.1
docker exec doc301-secure id -u
docker inspect doc301-secure --format 'User={{.Config.User}} Healthcheck={{json .Config.Healthcheck}}'
docker inspect doc301-secure --format '{{json .State.Health}}'
curl -fsS http://localhost:8000/health
```

The UID must not be zero. Wait for the healthcheck interval and confirm `healthy`. Compare image sizes; explain any measured change rather than claiming a guaranteed reduction. If Project 2 cleanup already removed the database, recreate it using that project's Step 4 first. Avoid port conflicts by removing the previous API container.

## Step 5: Tag, publish, pull, and verify

```bash
docker login
docker tag doc301-task-api:1.1 YOUR_DOCKERHUB_USERNAME/doc301-task-api:1.1
docker push YOUR_DOCKERHUB_USERNAME/doc301-task-api:1.1
docker rm -f doc301-secure
docker image rm YOUR_DOCKERHUB_USERNAME/doc301-task-api:1.1
docker pull YOUR_DOCKERHUB_USERNAME/doc301-task-api:1.1
docker run -d --name doc301-published --network doc301-net -p 8000:8000 \
  -e "DATABASE_URL=postgresql+psycopg2://taskforge:${POSTGRES_PASSWORD}@doc301-db:5432/taskforge" \
  YOUR_DOCKERHUB_USERNAME/doc301-task-api:1.1
curl -fsS http://localhost:8000/health
docker inspect doc301-published --format '{{json .State.Health}}'
```

Replace the Docker Hub namespace with yours. Removing a local tag before pulling verifies registry retrieval, although Docker can reuse cached layers. Do not publish secrets or use a real database password for this exercise.

## Cleanup and evidence

```bash
docker rm -f doc301-published
```

Capture size comparison, Dockerfile, `.dockerignore`, non-root UID, healthy status, Docker Hub image URL, and successful pull. Retain the versioned image for Project 5.
