# Project 08: Troubleshoot and Recover a Broken Containerized Application — Detailed Reference Solution

**Course:** DOC-301 — Docker & Containerization  
**Source verification:** Paired against uploaded Project 08 requirements and uploaded original Project 08 reference solution.  
**Scope:** Beginner-friendly Bash/POSIX-shell walkthrough; commands are illustrative until run on a Docker host.

## What you are building

You are on call. A teammate hands you a broken Compose deployment. Users cannot create tasks, and one or more services are unhealthy or restarting. Restore service without deleting customer data.

## Requirement-by-requirement coverage

| # | Published requirement | Where it is demonstrated |
|---|---|---|
| 1 | Start from the instructor-supplied broken Compose configuration and a pre-existing database volume. | Guided implementation / investigation below; see verification checklist |
| 2 | Identify at least four independent faults, including a bad database hostname, an incorrect API port mapping, a failing healthcheck, and an invalid database credential. | Guided implementation / investigation below; see verification checklist |
| 3 | Gather evidence using `docker compose ps`, `logs`, `docker inspect`, `docker exec`, and network inspection. | Guided implementation / investigation below; see verification checklist |
| 4 | Correct the configuration without deleting the database volume. | Guided implementation / investigation below; see verification checklist |
| 5 | Demonstrate healthy services and successful task creation/retrieval. | Guided implementation / investigation below; see verification checklist |
| 6 | Write an incident report listing symptoms, root causes, fixes, verification, and prevention. | Guided implementation / investigation below; see verification checklist |

## Guided investigation and recovery

**Assessment boundary:** Start with the instructor's *broken* Compose deployment and the existing database volume. Do not use the working configuration as a replacement or erase data. The instructor setup guide is separate, under `instructor-setup/`, and should not be given to students before the exercise. This reference walkthrough names the four required faults because it is intended for review **after** an attempt.

### Step 1: Capture evidence before changing anything

```bash
docker compose config --quiet
docker compose up -d --build || true
docker compose ps -a
docker compose logs --tail=100 db api
docker network ls
```

`config --quiet` checks YAML and interpolation without exposing expanded credentials. `up` attempts startup; `|| true` allows the investigation to continue if Compose returns an error. `ps -a` includes failed and stopped containers. Logs reveal startup and connection errors. Save redacted output and the original broken `compose.yaml` before editing.

### Step 2: Diagnose the failing database healthcheck

```bash
DB_CID=$(docker compose ps -q db)
docker inspect "$DB_CID" --format '{{json .State.Health}}'
docker compose logs --tail=50 db
```

The seeded healthcheck refers to the nonexistent host `does-not-exist`. Its failure makes the `db` service unhealthy and blocks the API's `depends_on: condition: service_healthy` startup gate. Restore:

```yaml
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U taskuser -d tasks"]
      interval: 5s
      timeout: 3s
      retries: 10
```

Recreate and inspect: `docker compose up -d --force-recreate`, followed by `docker compose ps -a`. Fixing one problem may expose the next.

### Step 3: Diagnose the wrong database hostname

The broken `DATABASE_URL` uses `database`, but the actual Compose service is named `db`. On the Compose network, service names provide DNS records. A missing name produces a resolution error, which differs from a refused connection or bad password.

```bash
docker compose ps -a
docker compose logs --tail=100 api
docker network ls
docker compose exec db getent hosts db
```

If `getent` is unavailable, inspect the Compose network with `docker network inspect NETWORK_NAME`, using the actual name from `docker network ls`. Restore the connection host to `@db:5432/tasks`.

### Step 4: Diagnose the invalid database password

Once DNS resolves, the seeded wrong password causes PostgreSQL authentication to fail. The database's true credentials are the ones used when the existing volume was **first initialized**. Changing `POSTGRES_PASSWORD` in Compose does not reset an existing database user password. Restore the correct password in the API's connection URL, using the instructor-provided local value without printing it in the incident report. Recreate the API and inspect its logs. Never delete the volume to hide an authentication mismatch.

### Step 5: Correct the incorrect API port mapping

The seeded mapping is `"8000:8001"`, which directs host port 8000 to container port 8001. Uvicorn listens on **container port 8000**. Correct the Compose `api.ports` entry:

```yaml
    ports:
      - "8000:8000"
```

Verify with `docker compose port api 8000`. A published-port error is different from a failed database connection; investigate them separately.

### Step 6: Verify full recovery and data preservation

```bash
docker compose config --quiet
docker compose up -d --build --force-recreate
docker compose ps
curl -fsS http://localhost:8000/health
curl -fsS http://localhost:8000/tasks
curl -i -X POST http://localhost:8000/tasks -H 'Content-Type: application/json' -d '{"title":"recovered-service"}'
curl -fsS http://localhost:8000/tasks
```

Both services should operate normally, `GET /tasks` should still contain the instructor's **pre-existing task**, and POST should create a new task with HTTP 201. Verify `db` has no published host port using `docker compose ps` or `docker compose port db 5432`. A healthy API `/health` response alone does not prove database functionality; use the task endpoints.

### Step 7: Write the incident report

Include the observed impact, timeline, initial evidence, **four separate root causes**, corrective action for each, verification of restored functionality, proof the existing task survived, and prevention ideas. Examples of prevention include automated Compose validation, database readiness checks, deployment smoke tests, and secure credential handling. Redact passwords, connection URLs containing passwords, and tokens.

### Cleanup

Use `docker compose down` only after capturing evidence. Do **not** use `down -v`. Keep the named volume for assessment and review.

## Acceptance criteria to verify

- [ ] All four seeded faults are identified with supporting evidence.
- [ ] API health and task endpoints respond.
- [ ] A pre-existing task remains available.
- [ ] Database has no published host port.
- [ ] Incident report explains why each fix works.

## Constraints from the project

- Do not use `docker compose down -v` or delete volumes to make errors disappear.
- Preserve existing database records.
- Do not modify application source unless the supplied application is itself defective.
- Record evidence before making changes.

## Required deliverables

- Corrected Compose file, investigation command transcript, API results, and incident report.

## Original reference solution, retained for comparison

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
