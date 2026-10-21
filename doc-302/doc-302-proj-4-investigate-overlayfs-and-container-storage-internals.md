# Reference solution: Project 04 — Investigate OverlayFS and Container Storage Internals

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

## 1. Verify storage support

```bash
docker info --format 'Driver={{.Driver}} Root={{.DockerRootDir}}'
findmnt -T /var/lib/docker || true
```
Continue only if the daemon uses overlay2 on a compatible native Linux filesystem. Do not directly modify `/var/lib/docker`.

**Evidence to retain:** command, timestamp, relevant output, expected result, observed result, and interpretation.

## 2. Build controlled layers

```bash
mkdir -p /tmp/doc302-overlay && cd /tmp/doc302-overlay
cat > Dockerfile <<'EOF'
FROM alpine:3.20
RUN printf 'version-one\n' > /sample.txt
RUN printf 'version-two\n' > /sample.txt
CMD ["sleep","3600"]
EOF
docker build -t doc302-overlay:lab .
docker history doc302-overlay:lab
docker run -d --name doc302-overlay-a doc302-overlay:lab
docker run -d --name doc302-overlay-b doc302-overlay:lab
docker exec doc302-overlay-a sh -c 'echo modified > /sample.txt'
docker diff doc302-overlay-a
docker diff doc302-overlay-b
```
Only container A should show the modified file. Inspect `GraphDriver.Data` with `docker inspect`, but treat the paths as internal, implementation-dependent details.

**Evidence to retain:** command, timestamp, relevant output, expected result, observed result, and interpretation.

## 3. Demonstrate deletion and volume

```bash
docker exec doc302-overlay-a rm /sample.txt
docker diff doc302-overlay-a
docker volume create doc302-overlay-data
docker run --rm -v doc302-overlay-data:/data alpine:3.20 sh -c 'echo persistent > /data/item'
docker run --rm -v doc302-overlay-data:/data alpine:3.20 cat /data/item
docker system df -v
```
Explain that a whiteout hides a lower-layer file; it does not shrink the immutable image. Volumes persist independently of container writable layers.

**Evidence to retain:** command, timestamp, relevant output, expected result, observed result, and interpretation.

## Verification checklist

- [ ] Confirm Docker storage driver and backing filesystem
- [ ] Build a small layered test image with a file changed in successive layers
- [ ] Create two containers from the image and change a file in only one
- [ ] Compare docker diff, image history and docker system df output
- [ ] Delete a file in a container and explain whiteout semantics
- [ ] Compare behavior with a named volume
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
