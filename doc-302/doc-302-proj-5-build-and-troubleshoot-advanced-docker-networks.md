# Project 05: Build and Troubleshoot Advanced Docker Networks | Detailed Reference Solution

**Course:** DOC-302 Advanced Docker & Containerization  
**Source:** Uploaded project 05 brief  
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

1. Create separate frontend and backend bridge networks
2. Attach the API to both and database only to backend
3. Inspect bridge and veth interfaces on the Linux host
4. Prove DNS resolution and service reachability from permitted peers
5. Test that the frontend cannot directly reach the database
6. Capture one packet flow and identify routing/NAT behavior
7. Optionally test macvlan only on a compatible dedicated Linux network

## Procedure

### 1. Prepare the starter and inspect its actual network behavior
```bash
git clone https://github.com/devopsforger/taskforge.git
cd taskforge
cp .env.example .env  # set a disposable POSTGRES_PASSWORD
# Do not commit .env
docker compose up -d --build
docker compose ps
docker compose config --services
```
TaskForge has frontend, API, and database. Its stock Compose file puts them on a shared network. The exercise changes network topology, not application code.

### 2. Split frontend and backend networks
Create `compose.networks.yaml` as a Compose override:
```yaml
services:
  frontend:
    networks: [front]
  api:
    networks: [front, back]
  db:
    networks: [back]
networks:
  front:
    driver: bridge
  back:
    driver: bridge
    internal: true
```
**Important:** A Compose override merges some fields. Confirm the merged `networks` for every service with `docker compose -f compose.yaml -f compose.networks.yaml config`; if the base file later adds explicit networks, check for unintended inheritance. The `internal` flag limits external routing but does not replace firewall policy or authentication.

```bash
docker compose -f compose.yaml -f compose.networks.yaml config --quiet
docker compose -f compose.yaml -f compose.networks.yaml up -d --build
docker network ls
docker network inspect "$(docker network ls --format '{{.Name}}' | grep '_front$' | head -1)"
```
Prefer using `docker compose ps -q SERVICE` to find container IDs instead of guessing generated names.

### 3. Verify permitted and denied paths
```bash
API=$(docker compose -f compose.yaml -f compose.networks.yaml ps -q api)
FRONT=$(docker compose -f compose.yaml -f compose.networks.yaml ps -q frontend)
DB=$(docker compose -f compose.yaml -f compose.networks.yaml ps -q db)
docker inspect "$API" --format '{{json .NetworkSettings.Networks}}'
docker inspect "$FRONT" --format '{{json .NetworkSettings.Networks}}'
docker inspect "$DB" --format '{{json .NetworkSettings.Networks}}'
curl -fsS http://127.0.0.1:8080/api/health
```
For DNS tests, attach an ephemeral diagnostics container to each named network and run `getent hosts api`, `getent hosts db`, or `nc -zv db 5432`. On `front`, the name `db` should not resolve; on `back`, `db` should resolve. Do not add a host-published PostgreSQL port.

### 4. Inspect host bridges and packet paths
```bash
ip -br link
ip -br addr
bridge link
sudo iptables -t nat -S | head -60  # or sudo nft list ruleset
sudo tcpdump -ni any 'tcp port 8080 or tcp port 5432' -c 20
```
Run the packet capture in one terminal and issue an HTTP request in another. Correlate the published frontend port with Docker's NAT/proxy implementation and container interfaces. Interface names, veth pairs, and firewall backends vary by host; record the actual mapping, not a guessed `docker0` path. Do not run optional macvlan on Wi-Fi, shared corporate, or production networks.

## Report and cleanup
Include a diagram, allowed/blocked connectivity matrix, bridge/veth evidence, and packet notes. Stop with `docker compose -f compose.yaml -f compose.networks.yaml down` **without `-v`**. Document any platform-specific network limitations.


## Required evidence and deliverables

- Network diagram
- Inspection commands and results
- Connectivity matrix
- Packet trace notes
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

### Network segmentation example
From TaskForge root, create `compose.networks.yaml`:
```yaml
services:
  frontend:
    networks: [frontnet]
  api:
    networks: [frontnet, backnet]
  db:
    networks: [backnet]
networks:
  frontnet: {}
  backnet:
    internal: true
```
```bash
docker compose -f compose.yaml -f compose.networks.yaml config --quiet
docker compose -f compose.yaml -f compose.networks.yaml up -d --build
docker network ls
docker compose -f compose.yaml -f compose.networks.yaml ps
curl -fsS http://127.0.0.1:8080/api/health
```
The base Compose file may define default network attachments, so **inspect the merged config** and confirm each service's final `networks` list before claiming isolation. To test DNS without changing the app image, use `docker run --rm --network <project>_frontnet busybox:1.36 nslookup api` and repeat for `db` (expected DNS failure on the frontend network). On the backend network, `nslookup db` should work. Capture `ip -br link`, `bridge link`, and `sudo tcpdump -ni <lab-bridge> port 5432` during an API request on a native Linux VM. Do not change host firewall rules on shared infrastructure.

### Evidence checklist for this exercise

- Capture exact commands and redacted output, including timestamps and TaskForge commit SHA.
- Explain what each check proves and what it cannot prove.
- Include a negative test, the successful recovery or expected observation, and cleanup without deleting persistent data.
- Commands are reviewed against the supplied starter structure but were not executed against a Docker daemon here.
