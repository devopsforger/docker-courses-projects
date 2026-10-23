# Project 02: Build and Run a Custom Docker Image — Updated Reference Solution

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
## Objective and important compatibility note

Build the TaskForge API into `doc301-task-api:1.0`, run it on host port 8000, inspect logs, and verify HTTP endpoints. **The published Project 2 expectation that GET requests work without PostgreSQL is incompatible with the linked TaskForge application.** For this starter, a temporary database is required. The original `GET /tasks` response is still `[]` on a fresh database, but not because database access is optional. Update the project brief if strict alignment is required.

## Step 1: Examine the starter

```bash
ls backend
cat backend/Dockerfile
cat backend/requirements.txt
```

The starter already provides a Dockerfile and the Python files. We will create a **course-specific Dockerfile** without modifying `main.py` or `requirements.txt`. The source entry point is `main:app`, not `app:app`.

## Step 2: Write `backend/Dockerfile.doc301`

```dockerfile
FROM python:3.13-slim
WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY main.py ./
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

`FROM` selects the runtime, `WORKDIR` sets the working directory, and `COPY` transfers files from the build context. Installing dependencies before copying application code allows Docker to reuse the dependency layer when only `main.py` changes. `EXPOSE` documents port 8000; only `docker run -p` publishes it. `CMD` starts Uvicorn and binds to all container interfaces.

## Step 3: Build and inspect

Run these commands from the **TaskForge repository root**:

```bash
docker build -f backend/Dockerfile.doc301 -t doc301-task-api:1.0 backend
docker image ls doc301-task-api
docker history doc301-task-api:1.0
docker image inspect doc301-task-api:1.0 --format '{{json .Config.Cmd}}'
```

The final `backend` is the build context. A Dockerfile cannot `COPY` files outside that context.

## Step 4: Provide the database TaskForge requires

```bash
docker network create doc301-net
docker volume create doc301-p2-pgdata
read -rsp 'Disposable training password (alphanumeric): ' POSTGRES_PASSWORD; echo
export POSTGRES_PASSWORD
docker run -d --name doc301-db --network doc301-net \
  -e POSTGRES_USER=taskforge -e POSTGRES_DB=taskforge \
  -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
  -v doc301-p2-pgdata:/var/lib/postgresql postgres:18.6-alpine
until docker exec doc301-db pg_isready -U taskforge -d taskforge; do sleep 2; done
```

PostgreSQL 18 uses `/var/lib/postgresql` for its persistent mount in the TaskForge starter. No database port is published to the host. `pg_isready` checks server availability, not authentication; the API request is the end-to-end test. Use a URL-safe password for this learning example.

## Step 5: Start and test the API

```bash
docker run -d --name doc301-api --network doc301-net -p 8000:8000 \
  -e "DATABASE_URL=postgresql+psycopg2://taskforge:${POSTGRES_PASSWORD}@doc301-db:5432/taskforge" \
  doc301-task-api:1.0
docker ps
docker logs --tail=50 doc301-api
curl -i http://localhost:8000/health
curl -i http://localhost:8000/tasks
curl -i -X POST http://localhost:8000/tasks -H 'Content-Type: application/json' -d '{"title":"First Docker task"}'
curl -fsS http://localhost:8000/tasks
```

Expect `GET /health` to return `{"status":"ok"}`, an empty array from `GET /tasks` before creation, HTTP 201 for POST, and a task object with `id`, `title`, and `done` afterwards. If the API exits, inspect logs, the database hostname, and the connection URL. TaskForge does **not** have the old sample's expected HTTP 503 behavior when no database is configured; it fails during startup.

## Step 6: Clean up

```bash
docker rm -f doc301-api doc301-db
docker network rm doc301-net
unset POSTGRES_PASSWORD
```

Keep the named volume unless intentionally deleting this exercise's data. Keep the image for Project 3.

## Verification checklist

- [ ] Dockerfile uses `main.py`, `main:app`, and the supplied requirements.
- [ ] Image has tag `doc301-task-api:1.0` and can be rebuilt.
- [ ] API listens on `0.0.0.0:8000` and host port 8000 responds.
- [ ] Logs show Uvicorn startup; GET and POST endpoints work with the database.
- [ ] README documents the TaskForge/database dependency and explains Dockerfile instructions.
