# Project 06: Implement Centralized Container Logging and Monitoring | Detailed Reference Solution

**Course:** DOC-302 Advanced Docker & Containerization  
**Source:** Uploaded project 06 brief  
**Purpose:** A reproducible instructor reference and guided walkthrough, not a replacement for the project brief.

## Starter repository and environment

**Starter application:** [TaskForge](https://github.com/devopsforger/taskforge). Clone it with `git clone https://github.com/devopsforger/taskforge.git` and `cd taskforge`. Record the commit using `git rev-parse HEAD`; use the course-approved release/tag if one is specified. The repository contains `backend/main.py`, `backend/requirements.txt`, `backend/Dockerfile`, `frontend/`, and `compose.yaml`. **Do not copy application source into the solution or rewrite it.**

**Important TaskForge behavior:** The backend requires `DATABASE_URL` on startup. Its `/health` endpoint checks PostgreSQL. The provided Compose stack includes `db`, `api`, and `frontend`, publishes the frontend on port **8080**, and exposes `/api/health` and `/api/tasks` through the frontend. The starter uses PostgreSQL **18.6-alpine** and mounts `pgdata` at `/var/lib/postgresql`. Preserve that version's mount layout; do not substitute the PostgreSQL 17 data path. All commands below assume a disposable Linux lab and Docker Compose v2 unless noted. Never use real credentials.

**Initial evidence:**
```bash
docker version
docker compose version
docker info --format 'Driver={{.Driver}} Cgroup={{.CgroupVersion}}'
uname -r
git rev-parse HEAD
```
Record the actual results in `REPORT.md`; do not invent output. If the exercise needs a dedicated test image, it is intentionally separate from TaskForge.


## Requirements covered

1. Configure Docker-supported log rotation per service
2. Deploy cAdvisor and Prometheus in an isolated lab
3. Scrape metrics and verify target health
4. Generate controlled application requests and compare metrics before and after
5. Simulate an application error and locate relevant logs
6. Document metric cardinality and privileged monitoring risks

## Procedure

### 1. Start from the actual TaskForge Compose stack
```bash
git clone https://github.com/devopsforger/taskforge.git
cd taskforge
cp .env.example .env  # choose a disposable password
docker compose up -d --build
curl -fsS http://127.0.0.1:8080/api/health
```
The starter API does not expose a Prometheus `/metrics` endpoint. This project collects container metrics through cAdvisor; do not claim that request counts or latency histograms are available from TaskForge without instrumentation.

### 2. Configure bounded Docker logs
Create `compose.observability.yaml`:
```yaml
x-log: &bounded-log
  driver: local
  options:
    max-size: "10m"
    max-file: "3"
services:
  frontend:
    logging: *bounded-log
  api:
    logging: *bounded-log
  db:
    logging: *bounded-log
```
`local` supports bounded storage and `docker logs` on current Docker Engine releases. Apply it by recreating the lab containers; an existing container's logging driver is not changed in place.
```bash
docker compose -f compose.yaml -f compose.observability.yaml config --quiet
docker compose -f compose.yaml -f compose.observability.yaml up -d --force-recreate
docker inspect "$(docker compose ps -q api)" --format '{{json .HostConfig.LogConfig}}'
```

### 3. Add cAdvisor and Prometheus
Create `prometheus.yml`:
```yaml
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: cadvisor
    static_configs:
      - targets: ['cadvisor:8080']
```
Append the following to `compose.observability.yaml` under `services` (same indentation as `api`):
```yaml
  cadvisor:
    image: ghcr.io/google/cadvisor:v0.53.0
    privileged: true # isolated Linux lab only; document why this is risky
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker:/var/lib/docker:ro
    expose: ["8080"]
  prometheus:
    image: prom/prometheus:v3.5.0
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
    ports:
      - "127.0.0.1:19090:9090"
    depends_on: [cadvisor]
```
The image tags are examples; verify registry availability and pin digests for the submitted lab. cAdvisor host mounts and privilege requirements vary with Engine, cgroups, and rootless installations. Run this **only** on a disposable VM, never on a shared host. A hardened alternative is to use a supported read-only metrics integration where available.

### 4. Verify and compare metrics
```bash
docker compose -f compose.yaml -f compose.observability.yaml up -d
docker compose -f compose.yaml -f compose.observability.yaml ps
curl -fsS 'http://127.0.0.1:19090/api/v1/targets' | head -c 2000
curl -fsS 'http://127.0.0.1:19090/api/v1/query?query=up%7Bjob%3D%22cadvisor%22%7D'
```
Query `container_cpu_usage_seconds_total` and `container_memory_working_set_bytes` in the Prometheus UI. Send 30 bounded requests:
```bash
for i in $(seq 1 30); do curl -fsS http://127.0.0.1:8080/api/tasks >/dev/null; done
docker compose logs --tail=50 api frontend
```
An application error can be simulated with an invalid task payload, but FastAPI's validation error may appear in access logs rather than a Python traceback. Record the HTTP status and the corresponding container logs. Compare before/after metrics; cAdvisor does not automatically supply per-route request counters.

## Evidence, risks, cleanup
Capture target `UP` state, metric queries, log-driver inspection, and error logs. Explain high-cardinality labels, privileged cAdvisor access, and that **collection is not centralized log aggregation**: this setup retains logs locally while centralizing metrics. If centralized log search is required, add an actual log collector/backend and document it separately. Run `docker compose -f compose.yaml -f compose.observability.yaml down` without `-v`.


## Required evidence and deliverables

- Compose monitoring configuration
- Prometheus scrape configuration
- Metrics screenshots or query output
- Logging retention evidence
- A concise `REPORT.md` explaining commands, observations, decisions and any unresolved limitations.

## Acceptance checklist

- Every required experiment is reproducible from documented commands
- Evidence demonstrates the observed state, not only the intended configuration
- The student can explain why each configuration change has the claimed effect
- The final lab state is verified using at least one independent test
- No real secrets or destructive host changes are included in the submission

## Suggested `REPORT.md` structure

1. **Environment:** VM distribution, kernel, Docker Engine/Compose, architecture, Git commit and image digests.
2. **Baseline and hypothesis:** what was expected and what you observed before changes.
3. **Commands and evidence:** exact commands, relevant redacted outputs, and timestamps.
4. **Interpretation:** why each observed result supports or refutes the hypothesis.
5. **Validation:** successful application/host checks and at least one negative or failure-path check.
6. **Cleanup and limitations:** resources removed, volumes preserved, any host-specific restrictions.

**Safety:** These are lab reference commands, not commands tested in this environment. Verify image tags, supported CLI options and paths on your VM. Do not copy application code into your submission, commit `.env`, expose credentials, or run destructive host commands on production systems.


## Practical verified-against-source walkthrough supplement

### Working container-metrics stack
Create `monitoring/prometheus.yml`:
```yaml
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: cadvisor
    static_configs:
      - targets: ['cadvisor:8080']
```
Create `compose.monitoring.yaml`:
```yaml
services:
  api:
    logging:
      driver: json-file
      options: {max-size: '10m', max-file: '3'}
  frontend:
    logging:
      driver: json-file
      options: {max-size: '10m', max-file: '3'}
  db:
    logging:
      driver: json-file
      options: {max-size: '10m', max-file: '3'}
  cadvisor:
    image: ghcr.io/google/cadvisor:v0.53.0
    privileged: true # lab-only: broad host access; document this risk
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker:/var/lib/docker:ro
    networks: [default]
  prometheus:
    image: prom/prometheus:v3.5.0
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml:ro
    ports: ['127.0.0.1:9090:9090']
    networks: [default]
```
```bash
mkdir -p monitoring
docker compose -f compose.yaml -f compose.monitoring.yaml config --quiet
docker compose -f compose.yaml -f compose.monitoring.yaml up -d
curl -fsS 'http://127.0.0.1:9090/api/v1/targets' | head -c 1000
for i in $(seq 1 40); do curl -fsS http://127.0.0.1:8080/api/health >/dev/null || true; done
docker compose -f compose.yaml -f compose.monitoring.yaml logs --tail=50 api
```
Check target health and `container_cpu_usage_seconds_total` / `container_memory_working_set_bytes` in Prometheus. TaskForge does not have an application `/metrics` endpoint. The cAdvisor image tag and host-mount compatibility must be verified on the chosen lab VM; if unsupported, record that limitation.

### Evidence checklist for this exercise

- Capture exact commands and redacted output, including timestamps and TaskForge commit SHA.
- Explain what each check proves and what it cannot prove.
- Include a negative test, the successful recovery or expected observation, and cleanup without deleting persistent data.
- Commands are reviewed against the supplied starter structure but were not executed against a Docker daemon here.
