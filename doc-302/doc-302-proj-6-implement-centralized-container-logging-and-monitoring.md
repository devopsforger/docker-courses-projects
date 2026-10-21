# Reference solution: Project 06 — Implement Centralized Container Logging and Monitoring

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

## 1. Set log limits

In your TaskForge Compose services, set:
```yaml
logging:
  driver: local
  options:
    max-size: "10m"
    max-file: "3"
```
The `local` driver provides bounded local storage; confirm support and inspect effective configuration using `docker inspect`. If your platform requires `json-file`, configure rotation explicitly.

**Evidence to retain:** command, timestamp, relevant output, expected result, observed result, and interpretation.

## 2. Add monitoring stack

Create a separate lab Compose file for Prometheus and cAdvisor. Example Prometheus scrape configuration:
```yaml
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: cadvisor
    static_configs:
      - targets: ["cadvisor:8080"]
```
Mount the config read-only. cAdvisor may need read-only host mounts such as `/sys` and Docker storage metadata; run it only on a disposable VM and document the visibility/security tradeoff. Do not publish Prometheus or cAdvisor ports publicly.

**Evidence to retain:** command, timestamp, relevant output, expected result, observed result, and interpretation.

## 3. Validate metrics and logs

```bash
docker compose -f monitoring.compose.yaml config
docker compose -f monitoring.compose.yaml up -d
docker compose -f monitoring.compose.yaml ps
docker logs --tail 50 <taskforge-api-container>
```
In Prometheus, confirm the cAdvisor target is UP and query `container_memory_working_set_bytes` or `rate(container_cpu_usage_seconds_total[5m])`. Metric names/labels vary by version. Generate a controlled workload, compare before and after, and document any missing data.

**Evidence to retain:** command, timestamp, relevant output, expected result, observed result, and interpretation.

## Verification checklist

- [ ] Configure Docker-supported log rotation per service
- [ ] Deploy cAdvisor and Prometheus in an isolated lab
- [ ] Scrape metrics and verify target health
- [ ] Generate controlled application requests and compare metrics before and after
- [ ] Simulate an application error and locate relevant logs
- [ ] Document metric cardinality and privileged monitoring risks
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
