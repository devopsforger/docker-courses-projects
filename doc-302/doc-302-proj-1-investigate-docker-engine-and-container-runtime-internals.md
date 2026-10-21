# Reference solution: Project 01 — Investigate Docker Engine and Container Runtime Internals

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

## 1. Trace components

```bash
docker version
ps -eo pid,ppid,comm,args | grep -E 'dockerd|containerd|runc' | grep -v grep
systemctl status docker containerd --no-pager
docker info --format '{{json .Runtimes}}'
```
The OCI runtime (often runc) is short-lived; not finding a persistent `runc` process is normal. The daemon receives API requests and delegates runtime operations to containerd.

**Evidence to retain:** command, timestamp, relevant output, expected result, observed result, and interpretation.

## 2. Start and inspect

```bash
docker run -d --name doc302-runtime nginx:1.27-alpine
docker inspect -f 'ID={{.Id}} PID={{.State.Pid}} STATUS={{.State.Status}}' doc302-runtime
PID=$(docker inspect -f '{{.State.Pid}}' doc302-runtime)
ps -o pid,ppid,comm,args -p "$PID"
readlink /proc/"$PID"/ns/pid
readlink /proc/1/ns/pid
```
Record the process tree using `pstree -ap "$PID"` (or `ps`). A container is an ordinary host process with namespaces and cgroups, not a separate kernel.

**Evidence to retain:** command, timestamp, relevant output, expected result, observed result, and interpretation.

## 3. Observe lifecycle

```bash
docker events --filter container=doc302-runtime --since 10m &
EVENT_PID=$!
docker stop doc302-runtime
docker start doc302-runtime
docker rm -f doc302-runtime
kill "$EVENT_PID" 2>/dev/null || true
```
Match event timestamps with inspect state and daemon journal output. The host PID may change after restart.

**Evidence to retain:** command, timestamp, relevant output, expected result, observed result, and interpretation.

## Verification checklist

- [ ] Capture client, server, containerd and runtime versions
- [ ] Identify daemon and containerd processes and their service status
- [ ] Start a named container and record its container ID, PID, state, and runtime metadata
- [ ] Inspect the host process tree and namespace identifiers
- [ ] Stop and remove the container and compare the observed state
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
