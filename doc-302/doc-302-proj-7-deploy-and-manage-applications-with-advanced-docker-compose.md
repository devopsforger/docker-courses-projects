# Reference solution: Project 07 — Deploy and Manage Applications with Advanced Docker Compose

> Instructor/reference material. This guide assumes a **disposable native Linux VM** with Docker Engine. Substitute the published, version-pinned TaskForge starter release for any application image mentioned. The application code lives in its own repository and is not reproduced here.

## 0. Establish a clean baseline

```bash
docker version
docker info --format 'Driver={.Driver} Cgroup={.CgroupVersion}'
docker compose version
uname -a
docker ps -a
```

Save the output. Confirm you are not connected to a production Docker context: `docker context show`. Create a lab working directory, and record changes in a terminal log.

## 1. Compose base

Create `compose.yaml` with `frontend`, `api`, and `db` services using the pinned TaskForge image references. Use an internal backend network, named PostgreSQL volume, and no public database port. Make the API depend on `db` with `condition: service_healthy`. Ensure the application reads the database password from a supported file path or adapter before claiming Compose secrets integration.

**Evidence to retain:** command, timestamp, relevant output, expected result, observed result, and interpretation.

## 2. Add profiles and overrides

```yaml
# compose.dev.yaml (illustrative override)
services:
  api:
    environment:
      LOG_LEVEL: debug
  frontend:
    ports:
      - "127.0.0.1:8080:80"
```
```yaml
# compose.prod.yaml (illustrative override)
services:
  api:
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 512M
```
Validate merged configurations:
```bash
docker compose -f compose.yaml -f compose.dev.yaml config
docker compose -f compose.yaml -f compose.prod.yaml config
```

**Evidence to retain:** command, timestamp, relevant output, expected result, observed result, and interpretation.

## 3. Scale and verify

```bash
docker compose -f compose.yaml -f compose.prod.yaml up -d --scale api=3
docker compose ps
```
Do not bind a fixed host port directly on each API replica. Put a reverse proxy or load-balancing frontend on the shared network and test repeated requests. Compose scaling does not guarantee production-grade high availability or zero-downtime upgrades.

**Evidence to retain:** command, timestamp, relevant output, expected result, observed result, and interpretation.

## Verification checklist

- [ ] Create base Compose services for frontend, API and PostgreSQL
- [ ] Add development and production override files
- [ ] Use profiles for optional debug or observability tools
- [ ] Supply database credentials through file-based secrets when supported by the app
- [ ] Configure healthchecks and conditional dependencies
- [ ] Scale the API behind an internal reverse proxy without fixed host ports per replica
- [ ] Validate merged configuration with docker compose config
- [ ] Report explains any deviations and platform limitations.
- [ ] No credentials or personal data are present in the submission.

## Troubleshooting decision guide

| Symptom | First check | Next action |
|---|---|---|
| Container exits immediately | `docker logs` and exit code | Reproduce with same entrypoint and environment |
| Service cannot connect | DNS, target port and network membership | Inspect networks and actual listener |
| Service is unhealthy | Healthcheck command and dependency readiness | Test endpoint from inside network |
| High CPU or OOM | `docker stats`, cgroup counters | Compare limits to workload and fix root cause |
| Behavior differs across machines | Kernel, architecture, Docker version | Record and isolate environment-specific differences |

## Cleanup

Only remove lab resources you created. Confirm the target before deletion. Do **not** remove shared volumes or networks. Example commands below apply only if those names exist:

```bash
docker rm -f doc302-runtime doc302-isolation doc302-overlay-a doc302-overlay-b doc302-db doc302-api doc302-web 2>/dev/null || true
docker network rm doc302-front doc302-back 2>/dev/null || true
# Keep volumes until backup and persistence verification is complete.
```

## Instructor notes

The expected outcome is evidence-based explanation. There may be multiple technically valid implementations. Assess correctness of reasoning and verification, not command memorization.
