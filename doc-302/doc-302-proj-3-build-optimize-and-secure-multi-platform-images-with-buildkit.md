# Reference solution: Project 03 — Build Optimize and Secure Multi Platform Images with BuildKit

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

## 1. Prepare build inputs

Use the TaskForge backend Dockerfile from the pinned starter release. Make it multi-stage: a dependency/build stage and a minimal runtime stage. Copy only installed runtime dependencies and application artifacts. Add `.dockerignore` entries for `.git`, caches, `.env`, tests and local virtual environments. Do not paste application source into the course solution.

**Evidence to retain:** command, timestamp, relevant output, expected result, observed result, and interpretation.

## 2. Use Buildx and cache

```bash
docker buildx version
docker buildx create --name doc302-builder --use --driver docker-container
docker buildx inspect --bootstrap
# From the backend build-context directory:
docker buildx build --progress=plain --platform linux/amd64 --load -t taskforge-api:doc302 .
docker image inspect taskforge-api:doc302 --format '{{.Size}}'
```
Repeat the build and compare timings. For remote caching, use `--cache-to type=registry,ref=YOUR_USER/taskforge-cache,mode=max` and `--cache-from type=registry,ref=YOUR_USER/taskforge-cache`; authenticate first.

**Evidence to retain:** command, timestamp, relevant output, expected result, observed result, and interpretation.

## 3. Publish attestations

```bash
# Replace YOUR_USER and use a registry that supports OCI attestations.
docker login
docker buildx build --platform linux/amd64,linux/arm64 \
  --sbom=true --provenance=mode=max \
  -t YOUR_USER/taskforge-api:doc302 --push .
docker buildx imagetools inspect YOUR_USER/taskforge-api:doc302
```
Inspect SBOM/provenance with registry tooling such as `docker buildx imagetools inspect --raw` or `docker scout`. Do not claim arm64 execution was tested unless run on native arm64 or a verified emulator. Keep credentials out of layers; use `RUN --mount=type=secret,id=...` only when required.

**Evidence to retain:** command, timestamp, relevant output, expected result, observed result, and interpretation.

## Verification checklist

- [ ] Create a multi-stage Dockerfile and .dockerignore
- [ ] Use pinned image versions and a non-root runtime user
- [ ] Use BuildKit secret mounts for any private build-time inputs; do not persist secrets
- [ ] Compare uncached and cached builds
- [ ] Build and push amd64 and arm64 images to an OCI registry
- [ ] Inspect manifest platforms, SBOM and provenance attestations
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
