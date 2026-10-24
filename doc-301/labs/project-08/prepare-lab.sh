#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
command -v docker >/dev/null || { echo 'Docker is required' >&2; exit 1; }
command -v git >/dev/null || { echo 'Git is required' >&2; exit 1; }
command -v curl >/dev/null || { echo 'curl is required' >&2; exit 1; }
if [[ ! -f .env ]]; then echo 'Create .env from .env.example first.' >&2; exit 1; fi
if [[ ! -d taskforge/.git ]]; then
  git clone https://github.com/devopsforger/taskforge.git taskforge
fi
if [[ -n "${TASKFORGE_COMMIT:-}" ]]; then
  git -C taskforge checkout --detach "$TASKFORGE_COMMIT"
fi
echo "TaskForge commit: $(git -C taskforge rev-parse HEAD)"
echo 'Starting the temporary healthy stack to prepare persistent sample data...'
docker compose -f compose.seed.yaml up -d --build
# Load LAB_PORT from .env without executing the file as shell code.
port=$(sed -n 's/^LAB_PORT=//p' .env | tail -n 1)
port=${port:-8080}
ready=0
for i in $(seq 1 90); do
  if curl --silent --fail "http://127.0.0.1:${port}/api/health" >/dev/null; then ready=1; break; fi
  sleep 2
done
if [[ "$ready" -ne 1 ]]; then
  echo 'The preparation stack did not become healthy. Inspect: docker compose -f compose.seed.yaml logs' >&2
  exit 1
fi
# Only insert if a recognizable lab task does not already exist.
if ! curl --silent --fail "http://127.0.0.1:${port}/api/tasks" | grep -Fq 'DOC-301 Project 08 preserved task'; then
  echo 'Creating the pre-existing task...'
  curl --fail --silent --show-error -X POST "http://127.0.0.1:${port}/api/tasks" \
    -H 'Content-Type: application/json' \
    -d '{"title":"DOC-301 Project 08 preserved task"}'
  echo
else
  echo 'Pre-existing task already present; no duplicate created.'
fi
echo 'Stopping the temporary healthy stack without removing its volume...'
docker compose -f compose.seed.yaml stop
echo 'Starting the incident environment...'
docker compose -f compose.faulty.yaml up -d --build || true
echo
echo 'Preparation complete. Preserve the database volume.'
echo 'Next: docker compose -f compose.faulty.yaml ps'
