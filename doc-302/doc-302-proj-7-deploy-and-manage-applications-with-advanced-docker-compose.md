# Project 07: Deploy and Manage Applications with Advanced Docker Compose | Detailed Reference Solution

**Course:** DOC-302 Advanced Docker & Containerization  
**Source:** Uploaded project 07 brief  
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

1. Create base Compose services for frontend, API and PostgreSQL
2. Add development and production override files
3. Use profiles for optional debug or observability tools
4. Supply database credentials through file-based secrets when supported by the app
5. Configure healthchecks and conditional dependencies
6. Scale the API behind an internal reverse proxy without fixed host ports per replica
7. Validate merged configuration with docker compose config

## Procedure

### 1. Baseline the starter Compose stack
```bash
git clone https://github.com/devopsforger/taskforge.git
cd taskforge
cp .env.example .env  # set a disposable POSTGRES_PASSWORD
docker compose config --quiet
docker compose up -d --build
curl -fsS http://127.0.0.1:8080/api/health
```
The starter already includes `frontend`, `api`, and `db`. Keep application source unchanged. The backend reads `DATABASE_URL`, **not** a `DATABASE_URL_FILE` variable; file-based secrets need a startup adapter if used.

### 2. Create explicit development and production overlays
`compose.dev.yaml`:
```yaml
services:
  api:
    environment:
      LOG_LEVEL: debug
  frontend:
    ports:
      - "127.0.0.1:8081:80"
```
**Warning:** Compose merges `ports` entries, so this override may publish both 8080 and 8081. If you need to replace a base port, use a supported Compose `!override` tag or move the port declaration into an environment-specific base file. Always inspect `docker compose config`.

`compose.prod.yaml`:
```yaml
services:
  api:
    restart: unless-stopped
    read_only: true
    tmpfs:
      - /tmp
    security_opt:
      - no-new-privileges:true
  db:
    restart: unless-stopped
  frontend:
    restart: unless-stopped
```
`read_only` is suitable only if the API and its dependencies do not need other writable paths. Confirm with a real request and logs. This is a production-like lab, not a production security certification.

### 3. Add an optional debug profile
`compose.debug.yaml`:
```yaml
services:
  debug:
    image: nicolaka/netshoot:v0.13
    profiles: ["debug"]
    command: ["sleep", "3600"]
```
Use `docker compose -f compose.yaml -f compose.debug.yaml --profile debug up -d` to start it. Debug containers have network visibility; do not leave them running unnecessarily.

### 4. Handle file-based credentials accurately
The PostgreSQL image supports `POSTGRES_PASSWORD_FILE`, but TaskForge's Python backend does not read `DATABASE_URL_FILE`. A correct adaptation is to mount a secret into `api` and run a **startup wrapper** that reads the secret and constructs `DATABASE_URL` before executing Uvicorn. That wrapper is deployment configuration, not application source. Avoid echoing credentials to logs or writing them into the image. Alternatively, document why the stock starter cannot meet the file-secret criterion without an adapter. Ensure the DB secret and API credential agree; changing the variable after a volume is initialized does not rotate PostgreSQL's existing password.

### 5. Scale API without per-replica host ports
The starter API has no host-published port; frontend proxies to service name `api`. Verify the frontend's proxy resolution strategy before scaling: a proxy that caches a single container IP may need reloads or DNS re-resolution to distribute traffic. On a disposable lab:
```bash
docker compose -f compose.yaml -f compose.prod.yaml config --quiet
docker compose -f compose.yaml -f compose.prod.yaml up -d --build --scale api=2
docker compose -f compose.yaml -f compose.prod.yaml ps api
curl -fsS http://127.0.0.1:8080/api/health
```
Inspect frontend Nginx behavior and confirm requests can reach both replicas (for example, using proxy access logs or temporary per-replica tracing). Merely having two containers is **not** proof of load balancing. Do not add `container_name` or fixed `ports` to `api`.

## Verify and clean up
Capture merged configs, healthy DB dependency, scaling evidence, secret-handling decision, and requests after restart. Use `docker compose -f compose.yaml -f compose.prod.yaml down` without `-v`.


## Required evidence and deliverables

- Compose files
- Validated merged configuration
- Scaling verification
- Secret-handling explanation
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

### Compose overrides, profiles, scaling, and secrets
Use TaskForge's base Compose and create `compose.dev.yaml`:
```yaml
services:
  api:
    environment:
      LOG_LEVEL: debug
  toolbox:
    image: busybox:1.36
    command: ['sleep','infinity']
    profiles: ['debug']
```
Create `compose.prod-lab.yaml`:
```yaml
services:
  api:
    restart: unless-stopped
    # Do not publish a fixed host port on this scaled service.
  db:
    restart: unless-stopped
  frontend:
    restart: unless-stopped
```
```bash
docker compose -f compose.yaml -f compose.dev.yaml config --quiet
docker compose -f compose.yaml -f compose.dev.yaml --profile debug up -d --build
docker compose -f compose.yaml -f compose.dev.yaml ps
docker compose -f compose.yaml -f compose.dev.yaml down
docker compose -f compose.yaml -f compose.prod-lab.yaml config --quiet
docker compose -f compose.yaml -f compose.prod-lab.yaml up -d --build --scale api=2
docker compose -f compose.yaml -f compose.prod-lab.yaml ps
curl -fsS http://127.0.0.1:8080/api/health
```
The frontend Nginx configuration may cache DNS or target a single API replica; verify traffic distribution separately. PostgreSQL supports `POSTGRES_PASSWORD_FILE` with a Compose secret, but TaskForge's API uses `DATABASE_URL` directly. A file-based DB password for PostgreSQL **alone** is not end-to-end secret handling. Explain this limitation and propose a wrapper/secret-aware app change separately, without claiming it is already supported.

### Evidence checklist for this exercise

- Capture exact commands and redacted output, including timestamps and TaskForge commit SHA.
- Explain what each check proves and what it cannot prove.
- Include a negative test, the successful recovery or expected observation, and cleanup without deleting persistent data.
- Commands are reviewed against the supplied starter structure but were not executed against a Docker daemon here.
