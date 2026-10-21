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
