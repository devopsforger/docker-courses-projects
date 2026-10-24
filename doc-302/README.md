# DOC-302 Reference Solutions

These nine step-by-step instructor reference guides correspond to the nine DOC-302 project briefs in `../projects/`. They contain practical Docker and Compose commands, examples, expected interpretations, evidence requirements, and cleanup guidance.

## How to use

1. Read the matching project brief first.
2. Clone [TaskForge](https://github.com/devopsforger/taskforge) and record the instructor-approved commit. Do not copy application source into the solution.
3. Use a disposable Linux VM for host-level labs; Docker Desktop does not expose the same host internals.
4. For Projects 8 and 9, prepare the matching `../instructor-setups/project-XX/compose.faulty.yaml`. The instructor must **withhold** `ANSWER-KEY.md` from students until grading.
5. Follow the numbered instructions, record actual command outputs and errors, and compare them with acceptance criteria.
6. Keep the TaskForge PostgreSQL 18.6 volume path `/var/lib/postgresql` and preserve database data.

## Critical TaskForge details

- Backend entrypoint: `backend/main.py`, not `app.py`.
- Backend requires `DATABASE_URL` and PostgreSQL at startup.
- The supplied stack has `db`, `api`, and `frontend`; frontend port 8080 proxies `/api/*`.
- The starter does **not** provide a Prometheus `/metrics` endpoint. Use cAdvisor for container metrics.
- The API does **not** support reading database credentials directly from a `_FILE` environment variable. Document the limitation in Project 7.

## Solution index

1. [doc-302-proj-1-investigate-docker-engine-and-container-runtime-internals](doc-302-proj-1-investigate-docker-engine-and-container-runtime-internals.md)
2. [doc-302-proj-2-explore-linux-namespaces-cgroups-and-container-isolation](doc-302-proj-2-explore-linux-namespaces-cgroups-and-container-isolation.md)
3. [doc-302-proj-3-build-optimize-and-secure-multi-platform-images-with-buildkit](doc-302-proj-3-build-optimize-and-secure-multi-platform-images-with-buildkit.md)
4. [doc-302-proj-4-investigate-overlayfs-and-container-storage-internals](doc-302-proj-4-investigate-overlayfs-and-container-storage-internals.md)
5. [doc-302-proj-5-build-and-troubleshoot-advanced-docker-networks](doc-302-proj-5-build-and-troubleshoot-advanced-docker-networks.md)
6. [doc-302-proj-6-implement-centralized-container-logging-and-monitoring](doc-302-proj-6-implement-centralized-container-logging-and-monitoring.md)
7. [doc-302-proj-7-deploy-and-manage-applications-with-advanced-docker-compose](doc-302-proj-7-deploy-and-manage-applications-with-advanced-docker-compose.md)
8. [doc-302-proj-8-diagnose-container-performance-and-runtime-failures](doc-302-proj-8-diagnose-container-performance-and-runtime-failures.md)
9. [doc-302-proj-9-harden-operate-and-recover-a-production-style-docker-environment](doc-302-proj-9-harden-operate-and-recover-a-production-style-docker-environment.md)

## Assessment and caveats

Assess actual observations, not memorized output. Capture software versions, container state, requests, resource counters, and redacted logs. No Docker daemon was available during authoring, so these are reviewed reference procedures, not runtime-certified transcripts. Validate image tags and host-specific commands in the teaching VM before class.
