# Project 07: Control and Monitor Container Resources — Detailed Reference Solution

**Course:** DOC-301 — Docker & Containerization  
**Source verification:** Paired against uploaded Project 07 requirements and uploaded original Project 07 reference solution.  
**Scope:** Beginner-friendly Bash/POSIX-shell walkthrough; commands are illustrative until run on a Docker host.

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

Continue from the working Project 6 `compose.yaml`. Under `services.api`, add:

```yaml
    mem_limit: 256m
    cpus: 0.50
    restart: unless-stopped
```

These are siblings of `build`, `ports`, and `depends_on`; do not create a second `restart` key. `mem_limit` sets a memory ceiling of 256 MiB (268,435,456 bytes). `cpus: 0.50` sets a CPU quota equivalent to half a logical CPU. `restart: unless-stopped` asks Docker to restart the container after failures unless an operator has deliberately stopped it. Limits do not guarantee the application will perform well under load.

### Step 2: Validate and recreate with the new settings

```bash
docker compose config --quiet
docker compose up -d --build --force-recreate
CID=$(docker compose ps -q api)
docker inspect "$CID" --format 'Memory={{.HostConfig.Memory}} NanoCpus={{.HostConfig.NanoCpus}} Restart={{.HostConfig.RestartPolicy.Name}}'
```

`--force-recreate` ensures the service container receives the new HostConfig settings. `docker compose ps -q api` returns its container ID. On a compatible Docker Engine, inspect should show `Memory=268435456`, `NanoCpus=500000000`, and `Restart=unless-stopped`. Docker Desktop resource availability depends on the virtual machine's settings.

### Step 3: Observe real usage and normal API operation

```bash
docker stats --no-stream "$CID"
curl -fsS http://localhost:8000/health
curl -fsS http://localhost:8000/tasks
docker inspect "$CID" --format 'Restarts={{.RestartCount}} OOMKilled={{.State.OOMKilled}} ExitCode={{.State.ExitCode}} Status={{.State.Status}}'
docker compose logs --tail=50 api
```

`docker stats --no-stream` prints one snapshot of CPU, memory, and other metrics. Usage is **not** the same as the configured limit. The health and tasks requests show whether the API still functions under the limits. `RestartCount` records container restarts; `State.OOMKilled` indicates whether Docker recorded an out-of-memory kill; `ExitCode` and logs help explain process exits.

### Step 4: Explain failure modes without generating unsafe load

A memory limit is a configured ceiling, not an observed failure. If a process exceeds the effective memory limit and is killed, Docker may record `OOMKilled=true`; exit code 137 is common, but 137 alone does not prove OOM because SIGKILL has other causes. An ordinary application error may exit with code 1 and a Python traceback in logs. A restart policy can bring a process back but cannot repair a bad password, unavailable database, or software defect. Do **not** intentionally exhaust host memory or run unbounded stress tests for this project.

### Step 5: Capture evidence and clean up

Document the Compose diff, inspect output, stats snapshot, successful HTTP responses, and a short comparison of OOM versus application errors. Then run:

```bash
docker compose down
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

## Original reference solution, retained for comparison

# Project 07: Control and Monitor Container Resources — Reference Solution

**Course:** DOC-301 — Docker & Containerization  
**Audience:** Instructors and students reviewing their completed attempt  
**Environment:** Docker Engine / Docker Desktop, POSIX shell examples unless stated otherwise

## What this solution demonstrates

Cpu and memory limits, stats, restart policies, inspect and failure analysis. The steps below are one valid implementation, not the only acceptable answer. Verify Docker and Compose versions in your own environment and never paste real secrets into submitted logs.

## Starting point

Use the functioning Project 6 Compose deployment and application. Do not create a separate stress-test application.

## Walkthrough

1. Under the `api` service in `compose.yaml`, add the following keys at the same indentation as `restart`:

```yaml
    mem_limit: 256m
    cpus: 0.50
    restart: unless-stopped
```

If `restart` already exists, keep only one copy. `mem_limit` limits memory to 256 MiB and `cpus` configures a quota equivalent to half a CPU. Exact enforcement and statistics depend on the Docker host and runtime environment.

2. Validate and recreate:

```bash
docker compose config --quiet
docker compose up -d --build --force-recreate
CID=$(docker compose ps -q api)
docker inspect "$CID" --format 'Memory={{.HostConfig.Memory}} NanoCpus={{.HostConfig.NanoCpus}} Restart={{.HostConfig.RestartPolicy.Name}}'
docker stats --no-stream "$CID"
```

Expected: `Memory=268435456`, `NanoCpus=500000000`, and `Restart=unless-stopped` on a supporting Docker Engine. CPU and memory usage shown by `docker stats` are observations, not proof of load capacity.

3. Verify normal behavior:

```bash
curl -fsS http://localhost:8000/health
curl -fsS http://localhost:8000/tasks
docker inspect "$CID" --format 'Restarts={{.RestartCount}} OOMKilled={{.State.OOMKilled}} ExitCode={{.State.ExitCode}}'
```

4. Interpret failures. A process killed for exceeding a memory limit may show `OOMKilled=true` and commonly exit code 137, but exit code 137 alone does not prove an OOM event. Application exceptions typically produce nonzero exit codes and error logs; restart policy may repeatedly restart them. Check logs, exit state and daemon events before attributing a cause. Do not force an OOM for this project.

5. Document the trade-off: limits protect host resources but overly strict limits can cause failures. Restart policies may restore a process after failure but cannot repair bad configuration, persistent dependency failures, or corrupted data.

## Troubleshooting

- `docker stats` shows unexpected CPU percentages: distinguish usage from configured quota.
- `OOMKilled=false` with a failed container: investigate logs rather than assuming memory exhaustion.
- Repeated restarts: inspect `docker compose logs --tail=100 api` and `RestartCount`.

## Cleanup

`docker compose down` to preserve named volumes. Restore or adjust resource settings for the next exercise.

## Verification checklist

- [ ] Every acceptance criterion in `project.md` has been demonstrated.
- [ ] Commands and observed outputs are included in the project README.
- [ ] No passwords, tokens, or `.env` files have been committed.
- [ ] Cleanup has not unintentionally removed persistent data.

## Instructor notes

Assess observable outcomes, not exact command memorization. Equivalent commands, base images, and file layouts are acceptable when they satisfy the requirements and do not undermine safety. Ask the student to explain *why* their configuration works and how they verified it.
