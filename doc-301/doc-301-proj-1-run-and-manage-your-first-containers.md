# Project 01: Run and Manage Your First Containers — Reference Solution

**Course:** DOC-301 — Docker & Containerization  
**Audience:** Instructors and students reviewing their completed attempt  
**Environment:** Docker Engine / Docker Desktop, POSIX shell examples unless stated otherwise

## What this solution demonstrates

Docker cli, image/container distinction, port publishing, lifecycle, logs and inspection. The steps below are one valid implementation, not the only acceptable answer. Verify Docker and Compose versions in your own environment and never paste real secrets into submitted logs.

## Walkthrough

1. Verify Docker is available: `docker version` and `docker info` (the daemon must be running).
2. Pull the image:

```bash
docker pull nginx:stable-alpine
docker image ls nginx
```

3. Create the container:

```bash
docker run -d --name doc301-web -p 8080:80 nginx:stable-alpine
```

`-d` detaches; `--name` provides a stable identifier; `-p 8080:80` forwards the host's TCP port 8080 to port 80 in the container. If 8080 is already in use, choose another free host port and adjust subsequent commands.

4. Inspect behavior:

```bash
docker ps
docker port doc301-web
docker logs doc301-web
docker inspect --format '{{.State.Status}}' doc301-web
curl -I http://localhost:8080
```

Expected: `running` and an HTTP `200 OK` response (headers can vary). `docker logs` may be empty until a request arrives.

5. Practice lifecycle commands:

```bash
docker stop doc301-web
docker ps -a
docker start doc301-web
curl -I http://localhost:8080
docker rm -f doc301-web
docker ps -a
docker image ls nginx
```

A container is a runnable instance of an image. Removing the instance does not remove the image.

## Troubleshooting

- `Cannot connect to the Docker daemon`: start Docker Desktop or the Docker daemon.
- `port is already allocated`: change host port (e.g., `-p 8081:80`).
- `container name already in use`: inspect or remove the existing container rather than silently overwriting it.

## Cleanup

`docker rm -f doc301-web` if it still exists. Keep the image for later practice, or remove it explicitly with `docker image rm nginx:stable-alpine` if unused.

## Verification checklist

- [ ] Every acceptance criterion in `project.md` has been demonstrated.
- [ ] Commands and observed outputs are included in the project README.
- [ ] No passwords, tokens, or `.env` files have been committed.
- [ ] Cleanup has not unintentionally removed persistent data.

## Instructor notes

Assess observable outcomes, not exact command memorization. Equivalent commands, base images, and file layouts are acceptable when they satisfy the requirements and do not undermine safety. Ask the student to explain *why* their configuration works and how they verified it.
