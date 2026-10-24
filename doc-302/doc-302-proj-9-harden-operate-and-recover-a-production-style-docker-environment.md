# Project 09: Harden Operate and Recover a Production Style Docker Environment | Detailed Reference Solution

**Course:** DOC-302 Advanced Docker & Containerization  
**Source:** Uploaded project 09 brief  
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

1. Audit image provenance, privileges, port exposure, credentials and resource policies
2. Document initial risks before making changes
3. Harden images and runtime configuration
4. Create and test a PostgreSQL backup and restore in an isolated database
5. Recover from the injected outage without deleting the only copy of persistent data
6. Validate functionality, persistence, security controls and rollback
7. Write an operator runbook and residual-risk assessment

## Procedure

### 1. Inventory the broken deployment without destroying evidence
Use the instructor-provided **broken TaskForge stack**; the uploaded brief does not specify the injected faults. Keep the provided database volume and preserve a copy of configuration before changes.
```bash
docker compose ps
docker compose config --quiet
docker compose images
docker compose logs --timestamps --tail=150
docker inspect "$(docker compose ps -q api)" --format '{{json .HostConfig.SecurityOpt}}'
docker inspect "$(docker compose ps -q db)" --format '{{json .Mounts}}'
docker network ls
docker volume ls
```
Do not print a fully expanded Compose configuration containing passwords into a shared report. Inventory image digests, user IDs, capabilities, read-only rootfs, published ports, restart policies, memory/CPU limits, and whether the DB volume exists.

### 2. Write a risk register before applying fixes
For each finding, record **asset, failure/attack scenario, likelihood, impact, proposed mitigation, verification, and residual risk**. Typical checks: exposed PostgreSQL port, root execution, privileged containers, missing resource limits, unbounded logs, image provenance, and credentials in Git. Only mark a finding confirmed when your actual configuration shows it.

### 3. Apply reversible hardening changes
Keep the starter backend code unchanged. A production-like Compose overlay may add:
```yaml
services:
  api:
    read_only: true
    tmpfs: [/tmp]
    security_opt: ["no-new-privileges:true"]
    cap_drop: [ALL]
    pids_limit: 128
    mem_limit: 512m
    cpus: 1.0
    restart: unless-stopped
  frontend:
    security_opt: ["no-new-privileges:true"]
    restart: unless-stopped
  db:
    restart: unless-stopped
```
Check the API with a real request after enabling a read-only root filesystem; some libraries need writable temporary paths. Do not blindly apply `cap_drop: [ALL]` to PostgreSQL or Nginx without validating startup and file ownership. Avoid exposing DB port 5432. Pin release images by digest after verifying the source and platform.

### 4. Create a consistent logical PostgreSQL backup
On the disposable stack, record a test task ID and title first:
```bash
curl -fsS http://127.0.0.1:8080/api/tasks
mkdir -p backups && chmod 700 backups
docker compose exec -T db pg_dump -U taskforge -d taskforge -Fc > backups/taskforge.dump
ls -lh backups/taskforge.dump
```
`pg_dump -Fc` creates a custom-format logical backup. A successful exit is not enough: restore into a **separate empty database** using a compatible PostgreSQL server, not into the live TaskForge database. For a controlled verification on the existing disposable DB instance, create a distinct database first:
```bash
docker compose exec -T db createdb -U taskforge taskforge_restore_test
docker compose exec -T db pg_restore -U taskforge -d taskforge_restore_test --no-owner --no-privileges < backups/taskforge.dump
docker compose exec -T db psql -U taskforge -d taskforge_restore_test -c 'SELECT count(*) FROM tasks;'
```
This is a separate **database**, not a separate PostgreSQL **instance**. For strict isolation, run a temporary second PostgreSQL 18.6-alpine container with its own new volume and restore there; document its network and credentials. Never overwrite the source DB during the exercise. Restrict access to backup files because they contain task data.

### 5. Restore the injected outage carefully
Use the instructor's fault bundle and collected evidence to identify the exact cause. Make one change at a time, preserving the original configuration for rollback. Verify the existing named volume still contains the original task. If the DB cannot start, investigate configuration, filesystem permissions, and version compatibility before considering any data operation. **Never delete or reinitialize the only copy of the volume.**

### 6. Verify recovery and rollback
```bash
docker compose config --quiet
docker compose up -d
docker compose ps
curl -fsS http://127.0.0.1:8080/api/health
curl -fsS http://127.0.0.1:8080/api/tasks
```
Compare task IDs before and after recovery. Verify ports, user, security options, resource policies, and a controlled restart. Document how to revert the overlay or deploy the previous pinned image without removing volumes. Do not claim rollback works until you demonstrate it on the lab.

## Operator runbook
Include detection signals, impact, first five diagnostic commands, escalation criteria, backup location and retention, restore procedure, verification commands, rollback steps, and remaining risks. The final report must separate **observed faults** from **hypothetical risks**.


## Required evidence and deliverables

- Risk assessment
- Hardened Compose files
- Backup/restore evidence
- Recovery runbook
- Post-recovery test results
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

### Concrete hardening and backup/recovery procedure
Copy `instructor-setups/project-09/compose.faulty.yaml` to TaskForge root and copy `Dockerfile.faulty` to `backend/Dockerfile.faulty`. Before changing the deployment:
```bash
docker compose -f compose.yaml -f compose.faulty.yaml up -d --build
docker compose -f compose.yaml -f compose.faulty.yaml ps
docker compose -f compose.yaml -f compose.faulty.yaml config --quiet
API=$(docker compose -f compose.yaml -f compose.faulty.yaml ps -q api)
docker inspect "$API" --format 'Privileged={{.HostConfig.Privileged}} User={{.Config.User}}'
docker compose -f compose.yaml -f compose.faulty.yaml port db 5432
# Logical backup. The DB can be healthy even if the API hostname is wrong.
docker compose -f compose.yaml -f compose.faulty.yaml exec -T db pg_dump -U taskforge -d taskforge -Fc > taskforge-backup.dump
ls -lh taskforge-backup.dump
```
Test restore in a **separate** throwaway PostgreSQL 18.6-alpine container, without touching the source volume:
```bash
docker run -d --name doc302-restore-db -e POSTGRES_USER=taskforge -e POSTGRES_PASSWORD=restoreonly -e POSTGRES_DB=taskforge postgres:18.6-alpine
until docker exec doc302-restore-db pg_isready -U taskforge -d taskforge; do sleep 2; done
docker exec -i doc302-restore-db pg_restore -U taskforge -d taskforge --no-owner --no-acl < taskforge-backup.dump
docker exec doc302-restore-db psql -U taskforge -d taskforge -c 'SELECT count(*) FROM tasks;'
docker rm -f doc302-restore-db
```
If `tasks` has not yet been created because the faulty API never started, the backup may be empty of application tables. First establish a healthy baseline and create a disposable task, then **reinject** the faulty override before taking recovery evidence. Document this setup requirement rather than fabricating restored rows.

Repair `compose.faulty.yaml`: remove `privileged: true`, remove `user: "0:0"`, remove DB host `ports`, and change `@missing-db:5432` to `@db:5432`. Run `docker compose -f compose.yaml -f compose.faulty.yaml up -d --force-recreate api db`; do **not** use `down -v`. Confirm health/tasks, DB host-port absence, and API non-root/non-privileged settings with `docker inspect`. Document rollback and residual risks, including environment-variable credentials.

### Evidence checklist for this exercise

- Capture exact commands and redacted output, including timestamps and TaskForge commit SHA.
- Explain what each check proves and what it cannot prove.
- Include a negative test, the successful recovery or expected observation, and cleanup without deleting persistent data.
- Commands are reviewed against the supplied starter structure but were not executed against a Docker daemon here.

**Additional injected fault:** `backend/Dockerfile.faulty` omits `USER 10001`. Rebuild from the secure original `backend/Dockerfile` or restore a non-root user in the faulty Dockerfile; confirm `.Config.User` and effective user inside the running container.
