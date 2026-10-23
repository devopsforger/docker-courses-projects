# Project 05: Connect Containers Using Docker Networks — Detailed Reference Solution

**Course:** DOC-301 — Docker & Containerization  
**Source verification:** Paired against uploaded Project 05 requirements and uploaded original Project 05 reference solution.  
**Scope:** Beginner-friendly Bash/POSIX-shell walkthrough; commands are illustrative until run on a Docker host.

## What you are building

The API and database are running in separate containers. Make them communicate over a private Docker network without exposing PostgreSQL to the host.

## Requirement-by-requirement coverage

| # | Published requirement | Where it is demonstrated |
|---|---|---|
| 1 | Create a user-defined bridge network `doc301-net`. | Guided implementation / investigation below; see verification checklist |
| 2 | Run a PostgreSQL container named `doc301-db` on that network with a named volume. | Guided implementation / investigation below; see verification checklist |
| 3 | Run the API image on the same network, configured to connect to host `doc301-db`. | Guided implementation / investigation below; see verification checklist |
| 4 | Create a task through the API and retrieve it. | Guided implementation / investigation below; see verification checklist |
| 5 | Prove that container DNS works and that PostgreSQL does not require a host port mapping. | Guided implementation / investigation below; see verification checklist |
| 6 | Explain why `localhost` is not the database hostname inside the API container. | Guided implementation / investigation below; see verification checklist |

## Guided implementation and explanations

### Step 1: Create an isolated user-defined bridge network

```bash
docker network create --driver bridge doc301-net
docker network inspect doc301-net
docker volume create doc301-net-pgdata
read -rsp 'Training database password (alphanumeric): ' POSTGRES_PASSWORD; echo
export POSTGRES_PASSWORD
```

A user-defined bridge network allows containers on it to resolve one another by name through Docker's embedded DNS. `--driver bridge` makes the network type explicit. The separate named volume prevents collisions with Project 4. Use an alphanumeric training password because it will be placed in a PostgreSQL connection URL; other characters may need percent encoding.

### Step 2: Start the database without publishing it

```bash
docker run -d --name doc301-db --network doc301-net \
  -e POSTGRES_USER=taskuser -e POSTGRES_DB=tasks \
  -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
  -v doc301-net-pgdata:/var/lib/postgresql/data postgres:17
until docker exec doc301-db pg_isready -U taskuser -d tasks; do sleep 2; done
```

`--network doc301-net` connects the container to the custom network. No `-p 5432:5432` is needed: the API will reach the database over the private network on its **container port** 5432.

### Step 3: Start the API using the database container name

```bash
docker run -d --name doc301-api --network doc301-net \
  -p 8000:8000 \
  -e "DATABASE_URL=postgresql://taskuser:${POSTGRES_PASSWORD}@doc301-db:5432/tasks" \
  doc301-task-api:1.1
```

`DATABASE_URL` supplies a connection string at runtime rather than embedding credentials into the Dockerfile. `doc301-db` is the database hostname **inside this Docker network**. `localhost` inside `doc301-api` would refer to the API container itself, not to PostgreSQL. The API port is published to the host for testing; the database port is not.

### Step 4: Verify DNS, connectivity, and database-backed requests

```bash
docker exec doc301-api python -c "import socket; print(socket.gethostbyname('doc301-db'))"
docker network inspect doc301-net
docker port doc301-db
curl -fsS http://localhost:8000/health
curl -i -X POST http://localhost:8000/tasks -H 'Content-Type: application/json' -d '{"title":"Learn Docker networking"}'
curl -fsS http://localhost:8000/tasks
```

DNS should resolve to an internal container IP. Do not copy that IP into configuration because it can change. `docker port doc301-db` should show no mapping. The POST should return HTTP **201** and an ID; GET should return the new task. These checks prove both network connectivity and real database writes.

### Step 5: Diagnose and clean up

If the API exits, inspect `docker logs doc301-api` and `docker network inspect doc301-net`. A DNS error suggests a wrong hostname or network membership. `connection refused` suggests the destination is not accepting connections. An authentication error suggests incorrect database credentials. Wait for database readiness before starting the API.

```bash
docker rm -f doc301-api doc301-db
docker network rm doc301-net
unset POSTGRES_PASSWORD
docker volume inspect doc301-net-pgdata
```

The named volume should remain. Include a simple network diagram in your README: `host -> API:8000 -> doc301-net -> doc301-db:5432 -> named volume`.

## Acceptance criteria to verify

- [ ] API creates and lists a task stored in PostgreSQL.
- [ ] `doc301-db` resolves inside the user-defined network.
- [ ] No host binding exists for database port 5432.
- [ ] Containers can be removed without deleting the named volume.

## Constraints from the project

- Use the Project 3 image or its equivalent.
- Do not hard-code credentials into the Dockerfile.
- Publish only the API port, not PostgreSQL.
- Avoid using container IP addresses as permanent configuration.

## Required deliverables

- Network/container commands, configuration method, API request results, and a short network explanation.

## Original reference solution, retained for comparison

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
