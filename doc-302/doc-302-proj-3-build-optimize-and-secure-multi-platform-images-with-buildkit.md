# Project 03: Build Optimize and Secure Multi Platform Images with BuildKit | Detailed Reference Solution

**Course:** DOC-302 Advanced Docker & Containerization  
**Source:** Uploaded project 03 brief  
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

1. Create a multi-stage Dockerfile and .dockerignore
2. Use pinned image versions and a non-root runtime user
3. Use BuildKit secret mounts for any private build-time inputs; do not persist secrets
4. Compare uncached and cached builds
5. Build and push amd64 and arm64 images to an OCI registry
6. Inspect manifest platforms, SBOM and provenance attestations

## Procedure

### 1. Prepare a dedicated build context
```bash
git clone https://github.com/devopsforger/taskforge.git
cd taskforge
git rev-parse HEAD
docker buildx version
docker buildx ls
```
Work from `backend/` as the build context. The starter backend uses `main.py` and SQLAlchemy; do not substitute the DOC-301 `app.py` example. Keep the starter application code unchanged. Save the existing `backend/Dockerfile` as a baseline, then create a new `backend/Dockerfile.buildkit` for this exercise.

### 2. Use a multi-stage, non-root image
Create `backend/Dockerfile.buildkit`:
```dockerfile
# syntax=docker/dockerfile:1.7
FROM python:3.13-slim AS builder
WORKDIR /build
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip wheel --wheel-dir /wheels -r requirements.txt

FROM python:3.13-slim
WORKDIR /app
RUN groupadd --system app && useradd --system --gid app --uid 10001 app
COPY --from=builder /wheels /wheels
COPY requirements.txt .
RUN pip install --no-cache-dir --no-index --find-links=/wheels -r requirements.txt \
    && rm -rf /wheels
COPY --chown=app:app main.py .
USER 10001
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```
Pin the base image **digest** in the submitted version after resolving it for the supported platforms; the version tag above is an illustrative starting point. The wheel stage keeps build artifacts out of the final image. Cache mounts speed dependency downloads without adding the cache directory to the image.

Create `backend/.dockerignore`:
```text
.git
.env
.env.*
__pycache__/
*.pyc
.venv/
*.log
```
Never put tokens in build arguments or `ENV`. If private dependencies are actually needed, use `RUN --mount=type=secret,id=...` and `docker buildx build --secret id=...,src=...`; no fake secret is required for the public TaskForge dependencies.

### 3. Compare build cache and image properties
```bash
docker buildx build --load --progress=plain -f backend/Dockerfile.buildkit -t taskforge-buildkit:lab ./backend
docker image inspect taskforge-buildkit:lab --format '{{.Size}} {{.Config.User}}'
docker history taskforge-buildkit:lab
# Repeat the identical build and compare timings and CACHED lines.
time docker buildx build --load --progress=plain -f backend/Dockerfile.buildkit -t taskforge-buildkit:lab ./backend
```
For a cold-build comparison, use a **new disposable builder** rather than pruning a shared cache. Compare against the starter `backend/Dockerfile` on the same machine and document both commands.

### 4. Publish multi-platform image with attestations
```bash
docker buildx create --name doc302-builder --driver docker-container --use
docker buildx inspect --bootstrap
# Set your own registry account before running:
export IMAGE="docker.io/YOUR_USERNAME/taskforge-api:doc302-lab"
docker login
docker buildx build --builder doc302-builder --platform linux/amd64,linux/arm64 \
  --provenance=mode=max --sbom=true -f backend/Dockerfile.buildkit \
  -t "$IMAGE" --push ./backend
docker buildx imagetools inspect "$IMAGE"
docker buildx imagetools inspect "$IMAGE" --raw
```
Confirm the manifest contains both platforms. Inspect the registry's attestation manifests for SBOM/provenance descriptors; actual display varies by Buildx and registry. `--push` is required for a multi-platform manifest; `--load` commonly loads only a single platform into the classic Docker image store. If emulation is unavailable, use native builders or document the limitation.

## Evidence and cleanup
Record image digest, per-platform metadata, cache timing, non-root user and attestation evidence. Do not publish private files or credentials. Remove only the builder you created with `docker buildx rm doc302-builder` when finished.


## Required evidence and deliverables

- Dockerfile and .dockerignore
- Build command transcript
- Image digest and manifest inspection
- Image size and cache comparison
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

### Concrete BuildKit procedure
From TaskForge root, create a separate `backend/Dockerfile.buildkit` with a dependency stage and a runtime stage, copying the existing `main.py` without modifying its contents:
```dockerfile
# syntax=docker/dockerfile:1.7
FROM python:3.13-slim AS builder
WORKDIR /build
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip pip wheel --wheel-dir /wheels -r requirements.txt
FROM python:3.13-slim
WORKDIR /app
RUN useradd -r -u 10001 appuser
COPY --from=builder /wheels /wheels
COPY requirements.txt .
RUN pip install --no-cache-dir --no-index --find-links=/wheels -r requirements.txt && rm -rf /wheels
COPY main.py .
USER 10001
EXPOSE 8000
CMD ["uvicorn","main:app","--host","0.0.0.0","--port","8000"]
```
```bash
printf '.git\n.env\n__pycache__\n*.pyc\n' > backend/.dockerignore
docker buildx version
docker buildx create --name doc302builder --driver docker-container --use || docker buildx use doc302builder
time docker buildx build --load --platform linux/amd64 -f backend/Dockerfile.buildkit -t taskforge-api:buildkit ./backend
time docker buildx build --load --platform linux/amd64 -f backend/Dockerfile.buildkit -t taskforge-api:buildkit ./backend
docker image inspect taskforge-api:buildkit --format '{{.Size}}'
# Set REGISTRY_IMAGE to a registry repository you own, e.g. docker.io/YOURUSER/taskforge-api:doc302
: "${REGISTRY_IMAGE:?Set REGISTRY_IMAGE to a repository you own}"
docker login
docker buildx build --platform linux/amd64,linux/arm64 -f backend/Dockerfile.buildkit --push --sbom=true --provenance=mode=max -t "$REGISTRY_IMAGE" ./backend
docker buildx imagetools inspect "$REGISTRY_IMAGE"
```
Use a dummy private input only if your build actually needs one; `RUN --mount=type=secret,id=...` is the mechanism, not `ARG` for credentials. Record the first and second build durations, pushed digest, architectures, and available attestation evidence. Multi-platform success depends on the builder's ARM64 capability.

### Evidence checklist for this exercise

- Capture exact commands and redacted output, including timestamps and TaskForge commit SHA.
- Explain what each check proves and what it cannot prove.
- Include a negative test, the successful recovery or expected observation, and cleanup without deleting persistent data.
- Commands are reviewed against the supplied starter structure but were not executed against a Docker daemon here.
