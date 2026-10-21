# Reference solution: Project 08 — Diagnose Container Performance and Runtime Failures

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

## 1. Deploy faulty fixture

Use `instructor-setups/doc-302-proj-8-instructor-setup.md` to create the **separate** broken lab bundle. Students receive only the broken fixture and the project brief, not the fault manifest. Verify that the lab VM is disposable.

**Evidence to retain:** command, timestamp, relevant output, expected result, observed result, and interpretation.

## 2. Collect objective evidence

```bash
docker compose -f broken.compose.yaml ps
docker compose -f broken.compose.yaml logs --timestamps --tail 150
docker stats --no-stream
docker inspect <affected-container> --format '{{json .State}}'
docker events --since 30m --until 0m
```
Check `docker inspect` for OOMKilled, exit code, health status, and configured limits. On cgroup v2 inspect `cpu.stat` for throttling and `memory.events` for OOM counters.

**Evidence to retain:** command, timestamp, relevant output, expected result, observed result, and interpretation.

## 3. Inspect safely and repair

```bash
PID=$(docker inspect -f '{{.State.Pid}}' <affected-container>)
sudo nsenter -t "$PID" -n ip route
sudo strace -f -tt -p "$PID" -o /tmp/doc302-strace.log
```
Attach `strace` only briefly to a process in the disposable lab; ptrace permission may be restricted. If a process exits too quickly, reproduce under a controlled debug container. Correct one fault at a time (e.g., undersized memory limit, invalid dependency hostname, broken healthcheck) and measure recovery.

**Evidence to retain:** command, timestamp, relevant output, expected result, observed result, and interpretation.

## Verification checklist

- [ ] Record initial symptoms and a reproducible request
- [ ] Collect docker stats, inspect, events and logs
- [ ] Check cgroup throttling and OOM indicators
- [ ] Use strace on a disposable lab process to investigate blocked calls
- [ ] Use nsenter only for controlled namespace inspection
- [ ] Correct faults one at a time and retest
- [ ] Produce a timeline and root-cause report
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
