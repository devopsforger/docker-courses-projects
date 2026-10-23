# Project 05: Connect Containers Using Docker Networks — Updated Reference Solution

**Course:** DOC-301 — Docker & Containerization  
**Application source:** [TaskForge](https://github.com/devopsforger/taskforge)  

## Starter application

Use the existing [TaskForge starter repository](https://github.com/devopsforger/taskforge), specifically [`backend/main.py`](https://github.com/devopsforger/taskforge/blob/master/backend/main.py) and [`backend/requirements.txt`](https://github.com/devopsforger/taskforge/blob/master/backend/requirements.txt). **Do not copy or rewrite the Python application source into this solution.** The Docker learning objectives are about packaging and operating the supplied application.

TaskForge differs from the original DOC-301 sample: it uses `main.py` (not `app.py`), SQLAlchemy, and a **mandatory** `DATABASE_URL`. It cannot serve `/health` or `/tasks` without a reachable database. `/health` checks database connectivity, and task records include `done`. Where the original project asks for a database-free API, this guide explains the necessary adaptation rather than pretending the starter supports it.

Clone once and work from the repository root:

```bash
git clone https://github.com/devopsforger/taskforge.git
cd taskforge
```

All examples use a disposable local password. Never commit `.env` or paste real credentials into reports. Commands are reference examples, not runtime-tested in this environment.
## Objective

Create a user-defined bridge network, run PostgreSQL without a host port, run the TaskForge API on the same network, prove DNS and task persistence. Use the Project 3 image `doc301-task-api:1.1`.

## Step 1: Network and volume

```bash
docker network create --driver bridge doc301-net
docker volume create doc301-net-pgdata
read -rsp 'Disposable training password (alphanumeric): ' POSTGRES_PASSWORD; echo
export POSTGRES_PASSWORD
docker network inspect doc301-net
```

A user-defined bridge network provides container-name DNS resolution. Keep the volume separate from Project 4 so their data does not collide.

## Step 2: Database, private to Docker

```bash
docker run -d --name doc301-db --network doc301-net \
  -e POSTGRES_USER=taskforge -e POSTGRES_DB=taskforge \
  -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
  -v doc301-net-pgdata:/var/lib/postgresql postgres:18.6-alpine
until docker exec doc301-db pg_isready -U taskforge -d taskforge; do sleep 2; done
docker port doc301-db
```

The empty `docker port` output is intentional. Other containers on `doc301-net` reach PostgreSQL on internal port 5432 without a host binding. PostgreSQL 18's mount path differs from the PostgreSQL 17 example in Project 4.

## Step 3: Run API using database container DNS

```bash
docker run -d --name doc301-api --network doc301-net -p 8000:8000 \
  -e "DATABASE_URL=postgresql+psycopg2://taskforge:${POSTGRES_PASSWORD}@doc301-db:5432/taskforge" \
  doc301-task-api:1.1
```

`doc301-db` is resolved inside the user-defined network. `localhost` inside the API would refer to the **API container itself**, not PostgreSQL. The URL uses the SQLAlchemy `postgresql+psycopg2` dialect required by the TaskForge dependencies. Do not use the old sample's plain `postgresql://taskuser:.../tasks` URL without reviewing driver compatibility.

## Step 4: Prove networking and data flow

```bash
docker exec doc301-api python -c "import socket; print(socket.gethostbyname('doc301-db'))"
docker network inspect doc301-net
docker port doc301-db
curl -fsS http://localhost:8000/health
curl -i -X POST http://localhost:8000/tasks -H 'Content-Type: application/json' -d '{"title":"Docker networking"}'
curl -fsS http://localhost:8000/tasks
```

The DNS lookup should return an internal address, not a fixed address to copy into configuration. POST should return HTTP 201; GET should show the task and its `done` state. This verifies the database connection beyond merely checking `/health`.

## Troubleshooting and cleanup

Use `docker logs doc301-api`, `docker logs doc301-db`, and `docker network inspect doc301-net` to distinguish DNS errors, connection refusal, and authentication failures. `pg_isready` is not a password verification tool.

```bash
docker rm -f doc301-api doc301-db
docker network rm doc301-net
unset POSTGRES_PASSWORD
docker volume inspect doc301-net-pgdata
```

Do not delete the named volume unless intentionally discarding this project's data.

## Verification checklist

- [ ] Both containers share `doc301-net`.
- [ ] API resolves `doc301-db` and creates/lists a task.
- [ ] Database port 5432 is not published to the host.
- [ ] Database data remains in a named volume after container removal.
