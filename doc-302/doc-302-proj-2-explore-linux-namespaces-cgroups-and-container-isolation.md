# Project 02: Explore Linux Namespaces Cgroups and Container Isolation | Detailed Reference Solution

**Course:** DOC-302 Advanced Docker & Containerization  
**Source:** Uploaded project 02 brief  
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

1. Run a long-lived container with memory and CPU limits
2. Compare namespace links for the host and container init process
3. Locate its cgroup path and inspect memory.max and cpu.max where supported
4. Repeat with a dropped capability and demonstrate a restricted operation
5. Explain why privileged containers weaken isolation

## Procedure

### 1. Run a limited, long-lived container
```bash
docker run -d --name doc302-isolation --memory=256m --cpus=0.50 alpine:3.21 sleep 3600
PID=$(docker inspect -f '{{.State.Pid}}' doc302-isolation)
docker inspect doc302-isolation --format 'Memory={{.HostConfig.Memory}} NanoCpus={{.HostConfig.NanoCpus}} Pid={{.State.Pid}}'
```
Use a disposable Alpine container, not TaskForge, because these tests examine Linux isolation rather than application behavior.

### 2. Compare namespace identifiers
```bash
sudo ls -l /proc/1/ns/{pid,mnt,net,uts,ipc,user}
sudo ls -l "/proc/$PID/ns/"
docker exec doc302-isolation sh -c 'echo "container PID=$$"; cat /proc/self/cgroup'
```
Compare inode numbers for each namespace. Some namespaces may be shared by design; do not claim that every identifier must differ. Host PID 1 and the container's PID 1 are different views of process identity.

### 3. Inspect cgroups
```bash
docker info --format 'Cgroup version: {{.CgroupVersion}}'
sudo cat "/proc/$PID/cgroup"
sudo cat "/proc/$PID/mountinfo" | grep cgroup | head
```
On a cgroup v2 host, `/proc/$PID/cgroup` usually contains `0::/path`. Find the matching path under `/sys/fs/cgroup`, then inspect `memory.max`, `memory.current`, `cpu.max`, and `cpu.stat` with `sudo cat`. Expect `memory.max` near 268435456 bytes and `cpu.max` representing half a CPU per period. If your host uses cgroup v1, document the different controller files instead of inventing v2 output.

### 4. Prove a dropped capability changes behavior
```bash
docker run --rm --cap-drop=CHOWN alpine:3.21 sh -c 'touch /tmp/owned; chown 1234:1234 /tmp/owned; echo exit=$?'
docker run --rm alpine:3.21 sh -c 'touch /tmp/owned; chown 1234:1234 /tmp/owned; echo exit=$?'
```
The first `chown` should fail with insufficient permission; the second should succeed in a standard rootful Docker setup. This is a controlled comparison, not proof that every security boundary is enforced. `--privileged` grants broad device and capability access and relaxes isolation; do **not** run a privileged container for this demonstration.

### 5. Verify and clean up
```bash
docker stats --no-stream doc302-isolation
docker rm -f doc302-isolation
```
Include a namespace table, cgroup values, the two capability command outputs, and an explanation of why privileges increase host risk.


## Required evidence and deliverables

- Namespace comparison
- Cgroup evidence
- Capability experiment
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

### Controlled isolation experiment
```bash
docker run -d --name doc302-isolation --memory 128m --cpus 0.5 --cap-drop ALL alpine:3.20 sleep 600
PID=$(docker inspect -f '{{.State.Pid}}' doc302-isolation)
sudo readlink /proc/1/ns/pid; sudo readlink "/proc/$PID/ns/pid"
sudo cat "/proc/$PID/cgroup"
docker inspect -f '{{.HostConfig.Memory}} {{.HostConfig.NanoCpus}} {{json .HostConfig.CapDrop}}' doc302-isolation
docker exec doc302-isolation sh -c 'cat /proc/self/status | grep CapEff'
docker exec doc302-isolation sh -c 'cat /sys/fs/cgroup/memory.max; cat /sys/fs/cgroup/cpu.max'
docker rm -f doc302-isolation
```
On cgroup v2, `memory.max` should represent 128 MiB (134217728 bytes), and `cpu.max` should express half a CPU quota. Actual cgroup visibility depends on the runtime. For a capability denial demonstration, compare `--cap-drop ALL` and a default container's `/proc/self/status` `CapEff` and document the difference; do not use `--privileged` as a troubleshooting shortcut.

### Evidence checklist for this exercise

- Capture exact commands and redacted output, including timestamps and TaskForge commit SHA.
- Explain what each check proves and what it cannot prove.
- Include a negative test, the successful recovery or expected observation, and cleanup without deleting persistent data.
- Commands are reviewed against the supplied starter structure but were not executed against a Docker daemon here.
