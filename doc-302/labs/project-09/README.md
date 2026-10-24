# Instructor setup: DOC-302 Project 09

**Deliberately faulty lab. Do not use production infrastructure.** This is an instructor-provided Compose override, not a modified TaskForge application or image.

1. Clone `https://github.com/devopsforger/taskforge` to a disposable Linux VM and record `git rev-parse HEAD`.
2. Create a local `.env` containing `POSTGRES_PASSWORD=<throwaway-alphanumeric-password>`; do not commit it.
3. Copy this folder's `compose.faulty.yaml` to the TaskForge repository root, and copy `Dockerfile.faulty` into `taskforge/backend/`. Do not overwrite the original `backend/Dockerfile`.
4. From the TaskForge root run:

```bash
docker compose -f compose.yaml -f compose.faulty.yaml config --quiet
docker compose -f compose.yaml -f compose.faulty.yaml up -d --build
docker compose -f compose.yaml -f compose.faulty.yaml ps
curl -i --max-time 10 http://127.0.0.1:8080/api/health
```

Use the exact same `-f compose.yaml -f compose.faulty.yaml` flags for all scenario-specific Compose commands. **Do not run `docker compose down -v`**. Stop with `docker compose -f compose.yaml -f compose.faulty.yaml down` only after evidence is captured. The named volume is retained.