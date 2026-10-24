# Project 01: Investigate Docker Engine and Container Runtime Internals | Detailed Reference Solution

**Course:** DOC-302 Advanced Docker & Containerization  
**Source:** Uploaded project 01 brief  
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

1. Capture client, server, containerd and runtime versions
2. Identify daemon and containerd processes and their service status
3. Start a named container and record its container ID, PID, state, and runtime metadata
4. Inspect the host process tree and namespace identifiers
5. Stop and remove the container and compare the observed state

## Procedure

### 1. Identify the engine and runtime chain
```bash
docker version
docker info | grep -Ei 'runtimes|containerd|storage driver|cgroup'
sudo systemctl status docker containerd --no-pager
ps -eo pid,ppid,comm,args | grep -E '[d]ockerd|[c]ontainerd|[c]ontainerd-shim'
command -v runc && runc --version
```
The CLI talks to the Docker daemon. The daemon coordinates with containerd; a containerd shim supervises the running container and an OCI runtime such as runc sets up the process. Runtime details depend on your installation; record what is actually present rather than assuming the process names.

### 2. Start and inspect a disposable HTTP container
```bash
docker run -d --name doc302-runtime -p 127.0.0.1:18080:80 nginx:1.27-alpine
curl -I http://127.0.0.1:18080
docker inspect doc302-runtime --format 'ID={{.Id}} PID={{.State.Pid}} Status={{.State.Status}} Runtime={{.HostConfig.Runtime}}'
PID=$(docker inspect -f '{{.State.Pid}}' doc302-runtime)
ps -o pid,ppid,comm,args -p "$PID"
sudo pstree -aps "$PID"
sudo ls -l "/proc/$PID/ns/"
sudo cat "/proc/$PID/cgroup"
```
`State.Pid` is the host PID of the container's initial process. The namespace symlinks identify kernel isolation contexts; the cgroup path identifies resource accounting. An empty runtime field can mean Docker used its default runtime. Avoid treating Docker's JSON metadata as direct proof of every kernel setting.

### 3. Capture lifecycle and compare
Open a second terminal before stopping:
```bash
docker events --filter container=doc302-runtime
```
In the first terminal:
```bash
docker stop doc302-runtime
docker inspect doc302-runtime --format '{{.State.Status}} {{.State.Pid}} {{.State.ExitCode}}'
docker start doc302-runtime
docker inspect doc302-runtime --format '{{.State.Status}} {{.State.Pid}}'
curl -I http://127.0.0.1:18080
docker rm -f doc302-runtime
```
The PID changes when a new process is started; the old `/proc/PID` entry disappears after exit. Record a timeline with timestamps from `docker events`, the process tree, and your HTTP probe. Stop the events stream with Ctrl+C.

## Troubleshooting and cleanup
If `systemctl` is unavailable, identify the service manager and inspect processes directly. On Docker Desktop, run host-process commands inside its Linux VM or document why that is unavailable. If the HTTP probe fails, check `docker logs doc302-runtime` and the published port before changing anything. Confirm `docker ps -a --filter name=doc302-runtime` is empty after cleanup.


## Required evidence and deliverables

- Version and service evidence
- Annotated process tree
- Container lifecycle timeline
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

### Reproduce the Engine/runtime investigation
```bash
docker version; docker info --format 'Runtime={{json .Runtimes}} Driver={{.Driver}}'
systemctl status docker containerd --no-pager || true
ps -eo pid,ppid,comm,args | grep -E 'dockerd|containerd|runc' | grep -v grep
docker run -d --name doc302-runtime -p 18080:80 nginx:stable-alpine
CID=$(docker inspect -f '{{.Id}}' doc302-runtime)
PID=$(docker inspect -f '{{.State.Pid}}' doc302-runtime)
printf 'CID=%s PID=%s\n' "$CID" "$PID"
sudo ls -l "/proc/$PID/ns"
ps -o pid,ppid,comm,args -p "$PID"
curl -fsS http://127.0.0.1:18080/ >/dev/null
docker stop doc302-runtime; docker inspect -f '{{.State.Status}} {{.State.Pid}}' doc302-runtime
docker rm doc302-runtime
```
A running container is supervised through Docker Engine/containerd and an OCI runtime. `runc` may be short-lived, so absence from a later process snapshot does not mean it was never used. Record `docker events` in a second terminal if a lifecycle timeline is required.

### Evidence checklist for this exercise

- Capture exact commands and redacted output, including timestamps and TaskForge commit SHA.
- Explain what each check proves and what it cannot prove.
- Include a negative test, the successful recovery or expected observation, and cleanup without deleting persistent data.
- Commands are reviewed against the supplied starter structure but were not executed against a Docker daemon here.
