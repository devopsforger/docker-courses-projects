# Project 07: Control and Monitor Container Resources — Detailed Reference Solution

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

The service has limited capacity. Apply resource limits and demonstrate how to observe container usage and interpret failures.

## Requirement-by-requirement coverage

| # | Published requirement | Where it is demonstrated |
|---|---|---|
| 1 | Apply explicit memory and CPU limits to the API service in your Compose configuration. | Guided implementation / investigation below; see verification checklist |
| 2 | Set a suitable restart policy and explain when it helps or does not help. | Guided implementation / investigation below; see verification checklist |
| 3 | Observe the service using `docker stats` and `docker inspect`. | Guided implementation / investigation below; see verification checklist |
| 4 | Demonstrate how to inspect restart counts and container exit reasons. | Guided implementation / investigation below; see verification checklist |
| 5 | Test normal API behavior with limits enabled. | Guided implementation / investigation below; see verification checklist |
| 6 | Document how an out-of-memory kill differs from an application error. | Guided implementation / investigation below; see verification checklist |

## Guided implementation and explanations

### Step 1: Add explicit limits to the existing API service

Continue from the working Project 6 `compose.doc301.yaml`. Under `services.api`, add:

```yaml
    mem_limit: 256m
    cpus: 0.50
    restart: unless-stopped
```

These are siblings of `build`, `ports`, and `depends_on`; do not create a second `restart` key. `mem_limit` sets a memory ceiling of 256 MiB (268,435,456 bytes). `cpus: 0.50` sets a CPU quota equivalent to half a logical CPU. `restart: unless-stopped` asks Docker to restart the container after failures unless an operator has deliberately stopped it. Limits do not guarantee the application will perform well under load.

### Step 2: Validate and recreate with the new settings

```bash
docker compose -f compose.doc301.yaml config --quiet
docker compose -f compose.doc301.yaml up -d --build --force-recreate
CID=$(docker compose -f compose.doc301.yaml ps -q api)
docker inspect "$CID" --format 'Memory={{.HostConfig.Memory}} NanoCpus={{.HostConfig.NanoCpus}} Restart={{.HostConfig.RestartPolicy.Name}}'
```

`--force-recreate` ensures the service container receives the new HostConfig settings. `docker compose -f compose.doc301.yaml ps -q api` returns its container ID. On a compatible Docker Engine, inspect should show `Memory=268435456`, `NanoCpus=500000000`, and `Restart=unless-stopped`. Docker Desktop resource availability depends on the virtual machine's settings.

### Step 3: Observe real usage and normal API operation

```bash
docker stats --no-stream "$CID"
curl -fsS http://localhost:8000/health
curl -fsS http://localhost:8000/tasks
docker inspect "$CID" --format 'Restarts={{.RestartCount}} OOMKilled={{.State.OOMKilled}} ExitCode={{.State.ExitCode}} Status={{.State.Status}}'
docker compose -f compose.doc301.yaml logs --tail=50 api
```

`docker stats --no-stream` prints one snapshot of CPU, memory, and other metrics. Usage is **not** the same as the configured limit. The health and tasks requests show whether the API still functions under the limits. `RestartCount` records container restarts; `State.OOMKilled` indicates whether Docker recorded an out-of-memory kill; `ExitCode` and logs help explain process exits.

### Step 4: Explain failure modes without generating unsafe load

A memory limit is a configured ceiling, not an observed failure. If a process exceeds the effective memory limit and is killed, Docker may record `OOMKilled=true`; exit code 137 is common, but 137 alone does not prove OOM because SIGKILL has other causes. An ordinary application error may exit with code 1 and a Python traceback in logs. A restart policy can bring a process back but cannot repair a bad password, unavailable database, or software defect. Do **not** intentionally exhaust host memory or run unbounded stress tests for this project.

### Step 5: Capture evidence and clean up

Document the Compose diff, inspect output, stats snapshot, successful HTTP responses, and a short comparison of OOM versus application errors. Then run:

```bash
docker compose -f compose.doc301.yaml down
```

This removes containers while retaining the database volume. Retain a working Compose configuration for Project 8.

## Acceptance criteria to verify

- [ ] Configured limits are visible in Docker inspect output.
- [ ] The API still responds to normal requests.
- [ ] The restart policy is visible in inspect output.
- [ ] Documentation correctly distinguishes memory limit, OOM kill, and ordinary exit.

## Constraints from the project

- Do not intentionally exhaust your host's memory.
- Do not generate unbounded load on shared systems.
- A restart policy is not a substitute for fixing a crash or for a readiness check.

## Required deliverables

- Compose changes, observed limits and stats, normal request results, and incident-analysis notes.

