# DOC-301 Project 08: Learner lab

This directory contains a deliberately faulty Docker Compose deployment of [TaskForge](https://github.com/devopsforger/taskforge). Investigate the deployment, correct its faults, and preserve its existing PostgreSQL task records. Do not edit TaskForge application source code.

## Requirements

- Docker Engine or Docker Desktop with Compose v2
- Git, curl, and a shell with Bash
- An available host port 8080 (or change `LAB_PORT` in `.env` before preparing)
- Internet access for the initial TaskForge clone and image builds

## Prepare the lab

From this directory:

```bash
cp .env.example .env
```

Change the sample credentials to disposable lab-only values. Do not commit `.env`.

Run the preparation script:

```bash
bash prepare-lab.sh
```

The script clones TaskForge into `./taskforge/`, starts a temporary working stack, creates a sample task in PostgreSQL, stops the temporary stack **without deleting its database volume**, and starts the incident environment. It prints the TaskForge commit SHA. Record it in your report. An instructor may supply a tested revision by setting `TASKFORGE_COMMIT` before running the script.

The initial task title is `DOC-301 Project 08 preserved task`. Your final evidence must show that this *same existing record* survives recovery. Do not recreate it to simulate preservation.

## Investigate

Start with:

```bash
docker compose -f compose.faulty.yaml ps
docker compose -f compose.faulty.yaml logs --tail=100
docker compose -f compose.faulty.yaml config
curl -i http://127.0.0.1:8080/api/health
```

If you changed `LAB_PORT`, use that host port for HTTP requests.

Use the project brief for the investigation and submission requirements. The lab contains multiple independent configuration faults. Diagnose each one and verify corrections individually.

**Do not run `docker compose down -v`, delete the `pgdata` volume, or modify application source.** Keep the original configuration as evidence. Do not commit `.env` or the locally cloned `taskforge/` directory.

## File guide

- `Dockerfile.faulty`: API build instructions used by the exercise
- `compose.faulty.yaml`: incident deployment to investigate and repair
- `compose.seed.yaml`: temporary healthy configuration used **only to prepare initial data**; not the incident solution
- `.env.example`: disposable environment-variable template
- `prepare-lab.sh`: repeatable preparation script
- `.gitignore`: excludes secrets and the locally cloned TaskForge source

**Important:** `compose.seed.yaml` is included so the database can be initialized reproducibly. It is not an answer key, and you should not substitute it for your own investigation and corrections.
