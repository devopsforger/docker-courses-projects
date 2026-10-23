# Project 01: Run and Manage Your First Containers — Detailed Reference Solution

**Course:** DOC-301 — Docker & Containerization  
**Scope:** Step-by-step Docker reference; not runtime-tested here.

## What you are building

A team needs a temporary web server for a local demonstration. Run Nginx using an official image without installing Nginx on the host.

## Requirement-by-requirement coverage

| # | Published requirement | Where it is demonstrated |
|---|---|---|
| 1 | Pull the official `nginx:stable-alpine` image. | Guided implementation / investigation below; see verification checklist |
| 2 | Start a container named `doc301-web` in detached mode, publishing host port `8080` to container port `80`. | Guided implementation / investigation below; see verification checklist |
| 3 | Confirm the web server responds over HTTP. | Guided implementation / investigation below; see verification checklist |
| 4 | Show running and stopped containers, inspect the container, and read its logs. | Guided implementation / investigation below; see verification checklist |
| 5 | Stop, start, and remove the container without removing the image. | Guided implementation / investigation below; see verification checklist |

## Guided implementation and explanations

### Step 1: Verify Docker and inspect the image

```bash
docker version
docker info
docker pull nginx:stable-alpine
docker image ls nginx
docker image inspect nginx:stable-alpine --format 'Image={{.Id}} Size={{.Size}}'
```

`docker version` reports the client and server versions. If the server section is missing, the daemon is not available. `docker info` reports details about the engine. `docker pull` downloads the official Nginx image and its layers. The tag `stable-alpine` identifies the stable Alpine-based variant; a tag is not an immutable digest. `docker image ls` lists locally cached images. The inspect command shows the image ID and size in bytes. Your values will differ by platform and release.

### Step 2: Start a detached container

```bash
docker run -d --name doc301-web -p 8080:80 nginx:stable-alpine
```

`run` creates and starts a container. `-d` runs it in the background and prints a container ID. `--name` assigns the required human-readable name. `-p 8080:80` maps **host port 8080** to **container port 80**. The final argument is the image. Do not add `--privileged` or `--network host`. The image contains Nginx; no host Nginx installation is needed.

### Step 3: Test the service and inspect its state

```bash
docker ps
docker ps -a
docker port doc301-web
docker inspect doc301-web --format 'Status={{.State.Status}} Image={{.Config.Image}}'
curl -I http://localhost:8080
docker logs --tail=30 doc301-web
```

`docker ps` shows running containers; `-a` includes stopped ones. `docker port` shows the published port. `inspect` reads Docker's recorded configuration and state. `curl -I` makes a HEAD request; expect an HTTP success response, normally `200 OK`. The Nginx access log should show the request; log output depends on when you run the command. A running process alone does not prove the HTTP endpoint works, which is why the `curl` test matters.

### Step 4: Practice the full lifecycle

```bash
docker stop doc301-web
docker ps
docker ps -a
docker start doc301-web
docker restart doc301-web
curl -I http://localhost:8080
docker rm -f doc301-web
docker ps -a
docker image ls nginx
```

`stop` requests graceful shutdown. The stopped container disappears from `docker ps` but remains in `docker ps -a`. `start` reuses the same container. `restart` stops and starts it. `rm -f` removes the container, not its image. Verify the container name is absent and `nginx:stable-alpine` remains locally available.

### Step 5: Record submission evidence

Include the commands and **observed** outputs in `README.md`, explain that an image is a reusable template while a container is an instance, and explain the two sides of `8080:80`. Note any error you encountered and how you resolved it. Never fabricate output.

### Troubleshooting and cleanup

If port 8080 is occupied, change only the host side to `8081:80`, then use `http://localhost:8081`. If the daemon is unavailable, start Docker Desktop or the engine. If the name exists, inspect it before deciding whether to remove it. The final `docker rm -f doc301-web` is safe for this disposable Nginx exercise; do not remove the image because the project requires it to remain.

## Acceptance criteria to verify

- [ ] `curl -I http://localhost:8080` returns an HTTP response while running.
- [ ] The container can be stopped and started again.
- [ ] After removal, `docker ps -a` does not list `doc301-web`.
- [ ] The image remains visible in `docker image ls`.

## Constraints from the project

- Do not use `--privileged` or host networking.
- Do not bind to host port 80; use 8080 unless it is occupied.
- Do not use a Dockerfile in this project.

## Required deliverables

- A terminal transcript of the key commands.
- A short README describing image versus container and why port mapping is needed.

