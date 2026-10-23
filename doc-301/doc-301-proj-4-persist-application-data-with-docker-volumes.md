# Project 04: Persist Application Data with Docker Volumes — Detailed Reference Solution

**Course:** DOC-301 — Docker & Containerization  
**Source verification:** Paired against uploaded Project 04 requirements and uploaded original Project 04 reference solution.  
**Scope:** Beginner-friendly Bash/POSIX-shell walkthrough; commands are illustrative until run on a Docker host.

## What you are building

Your team wants to store tasks in PostgreSQL. Demonstrate that database records outlive a disposable database container.

## Requirement-by-requirement coverage

| # | Published requirement | Where it is demonstrated |
|---|---|---|
| 1 | Create a named volume called `doc301-pgdata`. | Guided implementation / investigation below; see verification checklist |
| 2 | Run PostgreSQL using a versioned official image, a database name, and credentials supplied at runtime. | Guided implementation / investigation below; see verification checklist |
| 3 | Insert and query at least two records using `psql` inside the container. | Guided implementation / investigation below; see verification checklist |
| 4 | Remove the container while preserving the volume. | Guided implementation / investigation below; see verification checklist |
| 5 | Recreate the database container with the same volume and verify the records still exist. | Guided implementation / investigation below; see verification checklist |
| 6 | Explain what happens if the volume is deleted. | Guided implementation / investigation below; see verification checklist |

## Guided implementation and explanations

### Step 1: Create a named volume and provide credentials safely

```bash
docker volume create doc301-pgdata
docker volume inspect doc301-pgdata
read -rsp 'Training database password: ' POSTGRES_PASSWORD; echo
export POSTGRES_PASSWORD
```

The volume is managed by Docker and exists independently of a container. `read -rsp` reads the password without echoing it to the terminal in Bash-compatible shells; `export` makes it available to the Docker command. This is for a local exercise, not a production secret-management design.

### Step 2: Start PostgreSQL 17 with persistent storage

```bash
docker run -d --name doc301-db \
  -e POSTGRES_USER=taskuser \
  -e POSTGRES_DB=tasks \
  -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
  -v doc301-pgdata:/var/lib/postgresql/data \
  postgres:17
```

`-e` supplies runtime environment variables; the database image uses these to initialize an **empty** data directory. `-v` attaches the named volume to PostgreSQL 17's data directory. There is no `-p`, so PostgreSQL is not published to the host. Do not change PostgreSQL major versions while reusing the data directory without a proper database upgrade.

### Step 3: Insert and query two records

```bash
until docker exec doc301-db pg_isready -U taskuser -d tasks; do sleep 2; done
docker exec doc301-db psql -U taskuser -d tasks -c 'CREATE TABLE IF NOT EXISTS notes (id SERIAL PRIMARY KEY, body TEXT NOT NULL);'
docker exec doc301-db psql -U taskuser -d tasks -c "INSERT INTO notes (body) VALUES ('first'), ('second');"
docker exec doc301-db psql -U taskuser -d tasks -c 'SELECT * FROM notes ORDER BY id;'
docker port doc301-db
```

`docker exec` runs a command inside an existing container. `pg_isready` checks server availability. `psql -c` executes one SQL command. The query should show at least two rows. `docker port` should report no published ports. Record the actual query output before removal.

### Step 4: Remove the container, not its volume

```bash
docker rm -f doc301-db
docker volume ls
docker volume inspect doc301-pgdata
```

The container is gone but the volume remains. The named volume is not owned by the container lifecycle; Docker keeps it until explicitly removed.

### Step 5: Recreate and verify persistence

```bash
docker run -d --name doc301-db \
  -e POSTGRES_USER=taskuser -e POSTGRES_DB=tasks \
  -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
  -v doc301-pgdata:/var/lib/postgresql/data postgres:17
until docker exec doc301-db pg_isready -U taskuser -d tasks; do sleep 2; done
docker exec doc301-db psql -U taskuser -d tasks -c 'SELECT * FROM notes ORDER BY id;'
```

Both original rows should still exist. Reusing a nonempty data directory does **not** reinitialize users or passwords. Deleting the volume would permanently remove this database's stored files unless a backup exists; a new volume would initialize a new empty database.

### Cleanup and evidence

```bash
docker rm -f doc301-db
unset POSTGRES_PASSWORD
```

Keep `doc301-pgdata` unless you deliberately choose to destroy the exercise data after assessment. Submit before-and-after SQL output, volume inspection, and a clear explanation of the difference between a container and its named volume.

## Acceptance criteria to verify

- [ ] At least two rows are present before container deletion.
- [ ] Both rows are still present after recreation with the same volume.
- [ ] No PostgreSQL host port is required.
- [ ] The volume exists independently of the container.

## Constraints from the project

- Never publish PostgreSQL port 5432 to the host unless needed for an explicit test.
- Do not commit credentials; use a local ignored environment file or interactive shell variables.
- Do not use `docker volume rm` on data you want to preserve.

## Required deliverables

- Commands, SQL statements, before/after query output, and an explanation of volume ownership.

## Original reference solution, retained for comparison

# Project 04: Persist Application Data with Docker Volumes — Reference Solution

**Course:** DOC-301 — Docker & Containerization  
**Audience:** Instructors and students reviewing their completed attempt  
**Environment:** Docker Engine / Docker Desktop, POSIX shell examples unless stated otherwise

## What this solution demonstrates

Named volumes, postgresql lifecycle, persistence, and destructive operations. The steps below are one valid implementation, not the only acceptable answer. Verify Docker and Compose versions in your own environment and never paste real secrets into submitted logs.

## Walkthrough

Use `postgres:17` for this exercise. PostgreSQL image storage paths and initialization behavior can differ across major versions; keep the same major version throughout the persistence test. This example mounts `/var/lib/postgresql/data`, the data directory used by the official PostgreSQL 17 image.

1. Set credentials in your shell **without recording them in the submitted transcript**:

```bash
read -rsp 'Local PostgreSQL password: ' POSTGRES_PASSWORD; echo
export POSTGRES_PASSWORD
```

For PowerShell, use an appropriate environment-variable method instead; the commands below use a POSIX shell. This local training password is not suitable for production secret management.

2. Create a volume and run the database:

```bash
docker volume create doc301-pgdata
docker run -d --name doc301-db \
  -e POSTGRES_USER=taskuser \
  -e POSTGRES_DB=tasks \
  -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
  -v doc301-pgdata:/var/lib/postgresql/data \
  postgres:17
```

3. Wait for readiness and write data:

```bash
until docker exec doc301-db pg_isready -U taskuser -d tasks; do sleep 2; done
docker exec doc301-db psql -U taskuser -d tasks -c 'CREATE TABLE IF NOT EXISTS notes (id SERIAL PRIMARY KEY, body TEXT NOT NULL);'
docker exec doc301-db psql -U taskuser -d tasks -c "INSERT INTO notes (body) VALUES ('first'), ('second');"
docker exec doc301-db psql -U taskuser -d tasks -c 'SELECT * FROM notes;'
docker volume inspect doc301-pgdata
```

4. Remove only the container, recreate it with **the same credentials, major image version, and volume**:

```bash
docker rm -f doc301-db
docker run -d --name doc301-db \
  -e POSTGRES_USER=taskuser -e POSTGRES_DB=tasks \
  -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
  -v doc301-pgdata:/var/lib/postgresql/data postgres:17
until docker exec doc301-db pg_isready -U taskuser -d tasks; do sleep 2; done
docker exec doc301-db psql -U taskuser -d tasks -c 'SELECT * FROM notes;'
```

The two rows should remain. PostgreSQL initialization environment variables only initialize a **new, empty** data directory; changing them does not reset credentials in an existing database.

## Troubleshooting

- Initialization fails: check `docker logs doc301-db` and that the volume was not initialized by a different PostgreSQL major version.
- `pg_isready` succeeds but SQL fails: readiness is not proof of correct credentials or table existence.
- Lost data: confirm the exact same named volume was mounted and that you did not delete it.

## Cleanup

```bash
docker rm -f doc301-db
unset POSTGRES_PASSWORD
```

**Keep `doc301-pgdata` for further practice.** To permanently delete its contents only when no longer needed: `docker volume rm doc301-pgdata`.

## Verification checklist

- [ ] Every acceptance criterion in `project.md` has been demonstrated.
- [ ] Commands and observed outputs are included in the project README.
- [ ] No passwords, tokens, or `.env` files have been committed.
- [ ] Cleanup has not unintentionally removed persistent data.

## Instructor notes

Assess observable outcomes, not exact command memorization. Equivalent commands, base images, and file layouts are acceptable when they satisfy the requirements and do not undermine safety. Ask the student to explain *why* their configuration works and how they verified it.
