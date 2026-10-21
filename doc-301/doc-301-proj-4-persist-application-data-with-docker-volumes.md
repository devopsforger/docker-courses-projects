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
