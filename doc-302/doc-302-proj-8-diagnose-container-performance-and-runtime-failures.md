# Project 08: Diagnose Container Performance and Runtime Failures | Detailed Reference Solution

**Course:** DOC-302 Advanced Docker & Containerization  
**Source:** Uploaded project 08 brief  
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

1. Record initial symptoms and a reproducible request
2. Collect docker stats, inspect, events and logs
3. Check cgroup throttling and OOM indicators
4. Use strace on a disposable lab process to investigate blocked calls
5. Use nsenter only for controlled namespace inspection
6. Correct faults one at a time and retest
7. Produce a timeline and root-cause report

## Procedure

### 1. Establish a safe baseline and capture symptoms
Use the **instructor-provided faulty scenario bundle** alongside the [TaskForge starter](https://github.com/devopsforger/taskforge). Use the concrete faulty override shipped with this package. See the scenario-specific walkthrough below. Before changing anything:
```bash
docker compose ps
docker compose logs --timestamps --tail=150 api db frontend
docker stats --no-stream
docker compose ps -q api | xargs -r docker inspect --format 'OOM={{.State.OOMKilled}} Exit={{.State.ExitCode}} Restart={{.RestartCount}}'
curl -i --max-time 10 http://127.0.0.1:8080/api/health
```
Record request latency, status code, and time. The backend's `/health` checks PostgreSQL, so a 5xx response can reflect database problems, not just an API process failure.

### 2. Correlate Docker and kernel evidence
```bash
docker events --since 30m --filter type=container
sudo journalctl -u docker --since '30 minutes ago' --no-pager | tail -100
API=$(docker compose ps -q api)
PID=$(docker inspect -f '{{.State.Pid}}' "$API")
sudo cat "/proc/$PID/cgroup"
docker inspect "$API" --format '{{json .HostConfig}}' > api-hostconfig.json
```
On cgroup v2, find the process's cgroup under `/sys/fs/cgroup` and read `cpu.stat` (`nr_throttled`, `throttled_usec`) and `memory.events` (`oom`, `oom_kill`). Compare two samples taken during a controlled request burst. A nonzero cumulative counter alone does not prove the current incident caused it.

### 3. Use strace on a disposable process
```bash
sleep 120 & TESTPID=$!
sudo strace -tt -p "$TESTPID" -o /tmp/doc302-strace.log & STRACEPID=$!
sleep 3
sudo kill -INT "$STRACEPID" 2>/dev/null || true
kill "$TESTPID" 2>/dev/null || true
```
This demonstrates blocked `nanosleep`/wait behavior without attaching to a sensitive process. `strace` may be restricted by ptrace settings; document the restriction rather than weakening security controls on a shared host. Never infer the application's bottleneck solely from this demonstration.

### 4. Inspect a container namespace safely
```bash
API=$(docker compose ps -q api)
PID=$(docker inspect -f '{{.State.Pid}}' "$API")
sudo nsenter -t "$PID" -n ip route
sudo nsenter -t "$PID" -n ss -lnt
```
This reads network namespace state from the disposable host. Do not change routes or firewall rules during observation. If `ip` or `ss` is absent on the host, install it on the VM rather than changing the application image.

### 5. Correct one documented fault at a time
Build a diagnosis table with symptom, evidence, hypothesis, change, retest, and outcome. Possible categories include CPU quota throttling, memory OOM, wrong DB credentials, DNS failure, or unhealthy PostgreSQL, but **do not assume any one is present**. After each isolated change, repeat the exact failing request, compare stats/counters, and capture a timestamped result.

## Final report and recovery
Include a chronological timeline, before/after latency and error counts, `OOMKilled` and throttling evidence, and a rollback command. Verify `GET /api/health` and `GET /api/tasks`, and create a disposable task if the scenario permits. Never run `docker compose down -v` to resolve an incident.


## Required evidence and deliverables

- Evidence log
- Diagnosis table
- Before/after measurements
- Incident report
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

### Concrete instructor-fault recovery
Copy `instructor-setups/project-08/compose.faulty.yaml` to TaskForge root and copy `Dockerfile.faulty` to `backend/Dockerfile.faulty` and start with:
```bash
docker compose -f compose.yaml -f compose.faulty.yaml config --quiet
docker compose -f compose.yaml -f compose.faulty.yaml up -d --build
docker compose -f compose.yaml -f compose.faulty.yaml ps
docker compose -f compose.yaml -f compose.faulty.yaml logs --timestamps --tail=100 api
curl -i --max-time 10 http://127.0.0.1:8080/api/health
API=$(docker compose -f compose.yaml -f compose.faulty.yaml ps -q api)
docker inspect -f 'CPU={{.HostConfig.NanoCpus}} Exit={{.State.ExitCode}} OOM={{.State.OOMKilled}}' "$API"
```
**Fault 1:** The API connection string uses `missing-db`; the real Compose hostname is `db`. Change that single string and recreate only the API with `docker compose -f compose.yaml -f compose.faulty.yaml up -d --force-recreate api`. Check `/api/health` and `/api/tasks`. **Fault 2:** The API has `cpus: 0.05`. Compare request latency and cgroup `cpu.stat` throttling counters under controlled load, then increase to `0.50` and retest. The throttling delta depends on workload; an idle API might show none.

For safe syscall evidence, `sleep 60 & P=$!; sudo strace -tt -p "$P" -o /tmp/doc302-strace.log` in one terminal, then interrupt `strace` and terminate the sleep. For namespaces, inspect the running API PID with `sudo nsenter -t "$(docker inspect -f '{{.State.Pid}}' "$API")" -n ip route`. If API is not running, resolve the DNS fault first. Record a before/after timeline, and never remove the database volume.

### Evidence checklist for this exercise

- Capture exact commands and redacted output, including timestamps and TaskForge commit SHA.
- Explain what each check proves and what it cannot prove.
- Include a negative test, the successful recovery or expected observation, and cleanup without deleting persistent data.
- Commands are reviewed against the supplied starter structure but were not executed against a Docker daemon here.

**Additional injected fault:** `backend/Dockerfile.faulty` checks HTTP port 8001, although TaskForge listens on 8000. After DNS recovery, inspect `docker inspect -f '{{json .State.Health}}' "$API"`, correct the healthcheck to port 8000, rebuild, and confirm healthy status.
