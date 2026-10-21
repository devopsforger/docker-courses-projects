# Reference solution: Project 05 — Build and Troubleshoot Advanced Docker Networks

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

## 1. Build segmented networks

```bash
docker network create doc302-front
docker network create doc302-back
docker run -d --name doc302-db --network doc302-back postgres:16-alpine \
  -e POSTGRES_PASSWORD=lab-only-change-me
docker run -d --name doc302-api --network doc302-back alpine:3.20 sleep 3600
docker network connect doc302-front doc302-api
docker run -d --name doc302-web --network doc302-front alpine:3.20 sleep 3600
docker network inspect doc302-front doc302-back
```
This uses test processes to verify network topology. Replace them with the pinned TaskForge service images when validating the application.

**Evidence to retain:** command, timestamp, relevant output, expected result, observed result, and interpretation.

## 2. Test isolation and DNS

```bash
docker exec doc302-api getent hosts doc302-db || true
docker exec doc302-web getent hosts doc302-db || true
docker exec doc302-web getent hosts doc302-api || true
```
`getent` may not be installed in minimal images; use a disposable network troubleshooting container attached to the relevant network. DNS lookup failure and connection refusal are different outcomes.

**Evidence to retain:** command, timestamp, relevant output, expected result, observed result, and interpretation.

## 3. Inspect host datapath

```bash
ip -br link
ip route
docker network inspect doc302-back -f '{{json .Options}}'
sudo nft list ruleset | head -n 100
```
Locate Docker bridge and veth peers using `ip link` and `bridge link`. Use `tcpdump -ni <bridge> port 5432` during a controlled connection attempt. Firewall implementation varies across distributions; avoid changing host firewall rules on a shared machine. Macvlan is optional and must not be attempted on an unmanaged LAN.

**Evidence to retain:** command, timestamp, relevant output, expected result, observed result, and interpretation.

## Verification checklist

- [ ] Create separate frontend and backend bridge networks
- [ ] Attach the API to both and database only to backend
- [ ] Inspect bridge and veth interfaces on the Linux host
- [ ] Prove DNS resolution and service reachability from permitted peers
- [ ] Test that the frontend cannot directly reach the database
- [ ] Capture one packet flow and identify routing/NAT behavior
- [ ] Optionally test macvlan only on a compatible dedicated Linux network
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
