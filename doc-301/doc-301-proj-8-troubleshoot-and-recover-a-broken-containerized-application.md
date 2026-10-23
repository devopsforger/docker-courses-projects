# Project 08: Troubleshoot and Recover a Broken Containerized Application — Detailed Reference Solution

**Course:** DOC-301 — Docker & Containerization  
**Scope:** Beginner-friendly Bash/POSIX-shell walkthrough; commands are illustrative until run on a Docker host.

## Starter application

Use the existing [TaskForge starter repository](https://github.com/devopsforger/taskforge), specifically [`backend/main.py`](https://github.com/devopsforger/taskforge/blob/master/backend/main.py) and [`backend/requirements.txt`](https://github.com/devopsforger/taskforge/blob/master/backend/requirements.txt). **Do not copy or rewrite the Python application source into this solution.** The Docker learning objectives are about packaging and operating the supplied application.

TaskForge differs from the original DOC-301 sample: it uses `main.py` (not `app.py`), SQLAlchemy, and a **mandatory** `DATABASE_URL`. It cannot serve `/health` or `/tasks` without a reachable database. `/health` checks database connectivity, and task records include `done`. Where the original project asks for a database-free API, this guide explains the necessary adaptation rather than pretending the starter supports it.

Clone once and work from the repository root:

```bash
git clone https://github.com/devopsforger/taskforge.git
cd taskforge
```

All examples use a disposable local password. Never commit `.env` or paste real credentials into reports. Commands are reference examples, not runtime-tested in this environment.

## What you are building

You are on call. A teammate hands you a broken Compose deployment. Users cannot create tasks, and one or more services are unhealthy or restarting. Restore service without deleting customer data.

## Requirement-by-requirement coverage

| # | Published requirement | Where it is demonstrated |
|---|---|---|
| 1 | Start from the instructor-supplied broken Compose configuration and a pre-existing database volume. | Guided implementation / investigation below; see verification checklist |
| 2 | Identify at least four independent faults, including a bad database hostname, an incorrect API port mapping, a failing healthcheck, and an invalid database credential. | Guided implementation / investigation below; see verification checklist |
| 3 | Gather evidence using `docker compose -f compose.doc301.yaml ps`, `logs`, `docker inspect`, `docker exec`, and network inspection. | Guided implementation / investigation below; see verification checklist |
| 4 | Correct the configuration without deleting the database volume. | Guided implementation / investigation below; see verification checklist |
| 5 | Demonstrate healthy services and successful task creation/retrieval. | Guided implementation / investigation below; see verification checklist |
| 6 | Write an incident report listing symptoms, root causes, fixes, verification, and prevention. | Guided implementation / investigation below; see verification checklist |

## Guided investigation and recovery

**Assessment boundary:** Start with the instructor's *broken* Compose deployment and the existing database volume. Do not use the working configuration as a replacement or erase data. The instructor setup guide is separate, under `instructor-setup/`, and should not be given to students before the exercise. This reference walkthrough names the four required faults because it is intended for review **after** an attempt.

### Step 1: Capture evidence before changing anything

```bash
docker compose -f compose.doc301.yaml config --quiet
docker compose -f compose.doc301.yaml up -d --build || true
docker compose -f compose.doc301.yaml ps -a
docker compose -f compose.doc301.yaml logs --tail=100 db api
docker network ls
```

`config --quiet` checks YAML and interpolation without exposing expanded credentials. `up` attempts startup; `|| true` allows the investigation to continue if Compose returns an error. `ps -a` includes failed and stopped containers. Logs reveal startup and connection errors. Save redacted output and the original broken `compose.doc301.yaml` before editing.

### Step 2: Diagnose the failing database healthcheck

```bash
DB_CID=$(docker compose -f compose.doc301.yaml ps -q db)
docker inspect "$DB_CID" --format '{{json .State.Health}}'
docker compose -f compose.doc301.yaml logs --tail=50 db
```

The seeded healthcheck refers to the nonexistent host `does-not-exist`. Its failure makes the `db` service unhealthy and blocks the API's `depends_on: condition: service_healthy` startup gate. Restore:

```yaml
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U taskforge -d taskforge"]
      interval: 5s
      timeout: 3s
      retries: 10
```

Recreate and inspect: `docker compose -f compose.doc301.yaml up -d --force-recreate`, followed by `docker compose -f compose.doc301.yaml ps -a`. Fixing one problem may expose the next.

### Step 3: Diagnose the wrong database hostname

The broken `DATABASE_URL` uses `database`, but the actual Compose service is named `db`. On the Compose network, service names provide DNS records. A missing name produces a resolution error, which differs from a refused connection or bad password.

```bash
docker compose -f compose.doc301.yaml ps -a
docker compose -f compose.doc301.yaml logs --tail=100 api
docker network ls
docker compose -f compose.doc301.yaml exec db getent hosts db
```

If `getent` is unavailable, inspect the Compose network with `docker network inspect NETWORK_NAME`, using the actual name from `docker network ls`. Restore the connection host to `@db:5432/taskforge`.

### Step 4: Diagnose the invalid database password

Once DNS resolves, the seeded wrong password causes PostgreSQL authentication to fail. The database's true credentials are the ones used when the existing volume was **first initialized**. Changing `POSTGRES_PASSWORD` in Compose does not reset an existing database user password. Restore the correct password in the API's connection URL, using the instructor-provided local value without printing it in the incident report. Recreate the API and inspect its logs. Never delete the volume to hide an authentication mismatch.

### Step 5: Correct the incorrect API port mapping

The seeded mapping is `"8000:8001"`, which directs host port 8000 to container port 8001. Uvicorn listens on **container port 8000**. Correct the Compose `api.ports` entry:

```yaml
    ports:
      - "8000:8000"
```

Verify with `docker compose -f compose.doc301.yaml port api 8000`. A published-port error is different from a failed database connection; investigate them separately.

### Step 6: Verify full recovery and data preservation

```bash
docker compose -f compose.doc301.yaml config --quiet
docker compose -f compose.doc301.yaml up -d --build --force-recreate
docker compose -f compose.doc301.yaml ps
curl -fsS http://localhost:8000/health
curl -fsS http://localhost:8000/tasks
curl -i -X POST http://localhost:8000/tasks -H 'Content-Type: application/json' -d '{"title":"recovered-service"}'
curl -fsS http://localhost:8000/tasks
```

Both services should operate normally, `GET /tasks` should still contain the instructor's **pre-existing task**, and POST should create a new task with HTTP 201. Verify `db` has no published host port using `docker compose -f compose.doc301.yaml ps` or `docker compose -f compose.doc301.yaml port db 5432`. TaskForge `/health` checks database connectivity, but also use task creation and retrieval to verify data operations.

### Step 7: Write the incident report

Include the observed impact, timeline, initial evidence, **four separate root causes**, corrective action for each, verification of restored functionality, proof the existing task survived, and prevention ideas. Examples of prevention include automated Compose validation, database readiness checks, deployment smoke tests, and secure credential handling. Redact passwords, connection URLs containing passwords, and tokens.

### Cleanup

Use `docker compose -f compose.doc301.yaml down` only after capturing evidence. Do **not** use `down -v`. Keep the named volume for assessment and review.

## Acceptance criteria to verify

- [ ] All four seeded faults are identified with supporting evidence.
- [ ] API health and task endpoints respond.
- [ ] A pre-existing task remains available.
- [ ] Database has no published host port.
- [ ] Incident report explains why each fix works.

## Constraints from the project

- Do not use `docker compose -f compose.doc301.yaml down -v` or delete volumes to make errors disappear.
- Preserve existing database records.
- Do not modify application source unless the supplied application is itself defective.
- Record evidence before making changes.

## Required deliverables

- Corrected Compose file, investigation command transcript, API results, and incident report.

