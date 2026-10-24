# Project 04: Investigate OverlayFS and Container Storage Internals | Detailed Reference Solution

**Course:** DOC-302 Advanced Docker & Containerization  
**Source:** Uploaded project 04 brief  
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

1. Confirm Docker storage driver and backing filesystem
2. Build a small layered test image with a file changed in successive layers
3. Create two containers from the image and change a file in only one
4. Compare docker diff, image history and docker system df output
5. Delete a file in a container and explain whiteout semantics
6. Compare behavior with a named volume

## Procedure

### 1. Verify storage prerequisites
```bash
docker info --format 'Storage driver={{.Driver}}'
findmnt -T /var/lib/docker -o TARGET,SOURCE,FSTYPE,OPTIONS
```
Use a native Linux Engine with `overlay2` for host-level OverlayFS inspection. Rootless Docker, Docker Desktop, and containerd snapshotter configurations can differ. Do not modify `/var/lib/docker` manually.

### 2. Build a deliberately layered test image
Create a new disposable directory outside TaskForge:
```bash
mkdir -p ~/doc302-overlay-lab && cd ~/doc302-overlay-lab
cat > Dockerfile <<'EOF'
FROM alpine:3.21
RUN mkdir -p /lab && printf 'layer one\n' > /lab/state.txt
RUN printf 'layer two\n' > /lab/state.txt
RUN printf 'delete me\n' > /lab/obsolete.txt
CMD ["sleep", "3600"]
EOF
docker build -t doc302-overlay:lab .
docker history --no-trunc doc302-overlay:lab
```
Each `RUN` creates a filesystem change in a layer. Replacing the file in a later layer does not rewrite the earlier layer.

### 3. Compare two containers and copy-on-write
```bash
docker run -d --name doc302-overlay-a doc302-overlay:lab
docker run -d --name doc302-overlay-b doc302-overlay:lab
docker exec doc302-overlay-a sh -c 'echo changed > /lab/state.txt; rm /lab/obsolete.txt'
docker exec doc302-overlay-a cat /lab/state.txt
docker exec doc302-overlay-b cat /lab/state.txt
docker diff doc302-overlay-a
docker diff doc302-overlay-b
docker system df -v
```
Container A has a writable-layer modification; container B still sees the original image. `docker diff` reports additions, changes, and deletions relative to the image. Deleting an image-layer file records a whiteout in the writable layer rather than removing it from the underlying image.

### 4. Inspect OverlayFS without touching Docker's data
```bash
docker inspect doc302-overlay-a --format '{{json .GraphDriver.Data}}'
```
On a compatible `overlay2` Engine this may show `LowerDir`, `UpperDir`, `MergedDir`, and `WorkDir`. Read their paths only on the disposable host, if available; never edit them. Record why those paths may be unavailable under other snapshotters.

### 5. Compare named-volume persistence
```bash
docker volume create doc302-overlay-data
docker run --rm -v doc302-overlay-data:/persist alpine:3.21 sh -c 'echo persisted > /persist/note.txt'
docker run --rm -v doc302-overlay-data:/persist alpine:3.21 cat /persist/note.txt
docker rm -f doc302-overlay-a doc302-overlay-b
docker volume inspect doc302-overlay-data
```
The volume persists after its container exits; a container writable layer does not. Remove the test volume only after recording evidence: `docker volume rm doc302-overlay-data`. Keep TaskForge database volumes untouched.


## Required evidence and deliverables

- Driver details
- Layer observations
- Copy-on-write explanation
- Volume comparison
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

### Reproducible layer experiment
```bash
docker info --format '{{.Driver}}'
mkdir -p /tmp/doc302-overlay-lab && cd /tmp/doc302-overlay-lab
cat > Dockerfile <<'EOF'
FROM alpine:3.20
RUN echo first > /example.txt
RUN echo second > /example.txt
CMD ["sleep", "600"]
EOF
docker build -t doc302-layer:lab .
docker run -d --name doc302-layer-a doc302-layer:lab
docker run -d --name doc302-layer-b doc302-layer:lab
docker exec doc302-layer-a sh -c 'echo changed > /example.txt; rm /etc/alpine-release'
docker diff doc302-layer-a
docker diff doc302-layer-b
docker history doc302-layer:lab
docker system df -v
docker volume create doc302-layer-data
docker run --rm -v doc302-layer-data:/data alpine:3.20 sh -c 'echo persistent > /data/item'
docker run --rm -v doc302-layer-data:/data alpine:3.20 cat /data/item
docker rm -f doc302-layer-a doc302-layer-b
```
`docker diff` reports writable-layer changes; the other container still sees the original image. A deletion creates whiteout semantics, not a modification of the immutable image. Inspect actual overlay2 paths only on a VM that uses that driver and only for your own lab containers.

### Evidence checklist for this exercise

- Capture exact commands and redacted output, including timestamps and TaskForge commit SHA.
- Explain what each check proves and what it cannot prove.
- Include a negative test, the successful recovery or expected observation, and cleanup without deleting persistent data.
- Commands are reviewed against the supplied starter structure but were not executed against a Docker daemon here.
