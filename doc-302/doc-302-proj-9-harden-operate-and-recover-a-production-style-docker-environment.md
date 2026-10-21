# Reference solution: Project 09 — Harden Operate and Recover a Production Style Docker Environment

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

## 1. Stage faulty deployment

Follow `instructor-setups/doc-302-proj-9-instructor-setup.md` to prepare a deliberately flawed TaskForge Compose deployment. Use synthetic data and take a database backup before injecting faults. Do not give students the answer key.

**Evidence to retain:** command, timestamp, relevant output, expected result, observed result, and interpretation.

## 2. Audit and harden

```bash
docker compose -f broken.compose.yaml config
docker compose -f broken.compose.yaml ps
docker inspect <api-container> --format 'Privileged={{.HostConfig.Privileged}} Readonly={{.HostConfig.ReadonlyRootfs}} User={{.Config.User}}'
docker image inspect <api-image> --format '{{.Id}}'
```
Check root execution, extra capabilities, published database ports, hard-coded secrets, floating tags, missing healthchecks, unbounded resources and logging. Replace insecure defaults with tested constraints; avoid enabling read-only root filesystems without accounting for writable temp paths.

**Evidence to retain:** command, timestamp, relevant output, expected result, observed result, and interpretation.

## 3. Backup, restore and recover

Use PostgreSQL logical backup against the disposable lab database:
```bash
# Run with lab credentials provided securely through the container environment.
docker exec <db-container> sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' > taskforge.backup
```
Restore into a **separate empty test database** with `pg_restore`, using matching PostgreSQL major versions where appropriate. Verify row counts and representative records before attempting incident recovery. Do not run `docker compose down -v` against the only data copy.

**Evidence to retain:** command, timestamp, relevant output, expected result, observed result, and interpretation.

## 4. Prove operations

Run health, API and UI smoke tests; restart services and confirm data remains intact. Document a rollback procedure pinned to known-good image digests. Record residual risks: single-host availability, credential rotation, restore time and monitoring gaps.

**Evidence to retain:** command, timestamp, relevant output, expected result, observed result, and interpretation.

## Verification checklist

- [ ] Audit image provenance, privileges, port exposure, credentials and resource policies
- [ ] Document initial risks before making changes
- [ ] Harden images and runtime configuration
- [ ] Create and test a PostgreSQL backup and restore in an isolated database
- [ ] Recover from the injected outage without deleting the only copy of persistent data
- [ ] Validate functionality, persistence, security controls and rollback
- [ ] Write an operator runbook and residual-risk assessment
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
