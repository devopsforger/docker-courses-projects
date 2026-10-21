# Reference solution: Project 02 — Explore Linux Namespaces Cgroups and Container Isolation

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

## 1. Launch bounded process

```bash
docker run -d --name doc302-isolation --memory 256m --cpus 0.5 --cap-drop ALL alpine:3.20 sleep 3600
PID=$(docker inspect -f '{{.State.Pid}}' doc302-isolation)
for n in pid net mnt uts ipc user; do printf '%s host=' "$n"; readlink /proc/1/ns/$n; printf 'container='; readlink /proc/$PID/ns/$n; done
```
User namespace links may match if user namespace remapping is disabled. Explain each observation.

**Evidence to retain:** command, timestamp, relevant output, expected result, observed result, and interpretation.

## 2. Inspect cgroups

```bash
docker inspect -f '{{.HostConfig.Memory}} {{.HostConfig.NanoCpus}}' doc302-isolation
cat /proc/$PID/cgroup
docker stats --no-stream doc302-isolation
```
On cgroup v2, locate the matching path under `/sys/fs/cgroup` and read `memory.max`, `cpu.max`, `memory.events`. The path depends on the cgroup driver and host distribution.

**Evidence to retain:** command, timestamp, relevant output, expected result, observed result, and interpretation.

## 3. Compare capabilities

```bash
docker exec doc302-isolation sh -c 'grep Cap /proc/1/status'
docker run --rm --cap-add NET_RAW alpine:3.20 sh -c 'grep Cap /proc/1/status'
```
Compare effective masks; do not assume `--cap-drop ALL` makes the process fully sandboxed. Check seccomp configuration with `docker inspect` and host kernel support.

**Evidence to retain:** command, timestamp, relevant output, expected result, observed result, and interpretation.

## Verification checklist

- [ ] Run a long-lived container with memory and CPU limits
- [ ] Compare namespace links for the host and container init process
- [ ] Locate its cgroup path and inspect memory.max and cpu.max where supported
- [ ] Repeat with a dropped capability and demonstrate a restricted operation
- [ ] Explain why privileged containers weaken isolation
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
