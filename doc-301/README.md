# DOC-301: Docker & Containerization (Beginner)

**Course:** [Docker & Containerization on DevOpsForger](https://devopsforger.com/courses/doc-301)

This directory contains the practical projects for DOC-301, an introductory course designed to teach students how to build, deploy, manage, secure, and troubleshoot containerized applications using Docker.

The projects follow a progressive approach. Students begin with basic container operations and gradually advance toward deploying and troubleshooting multi-container applications.

## Learning Objectives

By completing these projects, you should be able to:

- Run, inspect, and manage Docker containers.
- Build custom Docker images using Dockerfiles.
- Optimize images and apply basic container security practices.
- Publish images to Docker Hub.
- Persist application data using Docker volumes.
- Configure communication between containers using Docker networks.
- Deploy multi-container applications with Docker Compose.
- Configure container resource limits and monitor resource consumption.
- Diagnose and resolve common Docker problems.

## Prerequisites

Before starting, ensure you have:

- Docker Engine or Docker Desktop installed and running.
- Docker Compose available.
- A terminal or command-line interface.
- A code editor.
- Git installed.
- Basic knowledge of Docker concepts covered in the course.

Some projects require a Docker Hub account or a provided starter application.

## Projects

| # | Project | Difficulty |
|---|---|---|
| 01 | [Run and Manage Your First Containers](doc-301-proj-1-run-and-manage-your-first-containers.md) | Beginner |
| 02 | [Build and Run a Custom Docker Image](doc-301-proj-2-build-and-run-a-custom-docker-image.md) | Beginner |
| 03 | [Optimize, Secure, and Publish an Image](doc-301-proj-3-optimize-secure-and-publish-an-image.md) | Intermediate |
| 04 | [Persist Application Data with Docker Volumes](doc-301-proj-4-persist-application-data-with-docker-volumes.md) | Intermediate |
| 05 | [Connect Containers Using Docker Networks](doc-301-proj-5-connect-containers-using-docker-networks.md) | Intermediate |
| 06 | [Deploy a Multi-Container Application with Docker Compose](doc-301-proj-6-deploy-a-multi-container-application-with-docker-compose.md) | Intermediate |
| 07 | [Control and Monitor Container Resources](doc-301-proj-7-control-and-monitor-container-resources.md) | Intermediate |
| 08 | [Troubleshoot and Recover a Broken Containerized Application](doc-301-proj-8-troubleshoot-and-recover-a-broken-containerized-application.md) | Intermediate |

## How to Complete the Projects

We recommend completing the projects in order, as later projects build upon concepts introduced in earlier exercises.

For each project:

1. **Read the project description.** Understand the scenario, objectives, and expected outcome.
2. **Review the requirements.** Identify what you must build, configure, or troubleshoot.
3. **Prepare your environment.** Download any required starter files and confirm that Docker is working.
4. **Implement your solution.** Apply the concepts learned in the course.
5. **Verify your implementation.** Test your work against the acceptance criteria.
6. **Document your findings.** Explain your approach, technical decisions, challenges, and solutions.

The goal is not merely to execute Docker commands, but to understand what those commands do, why they are necessary, and how they affect the system.

## Starter Application

Some projects use a Task Management application to provide a consistent, realistic environment for learning Docker.

The application is provided separately and may include a frontend, backend API, and PostgreSQL database.

Students should use the starter application referenced in each project rather than building the application from scratch.

## Assessment and Verification

Each project contains acceptance criteria describing the expected results.

Your implementation should satisfy those criteria before you consider the project complete.

Where applicable, verify that:

- Containers start and behave as expected.
- Applications are accessible through the configured ports.
- Services communicate correctly.
- Data remains persistent when required.
- Security and resource configurations are applied correctly.
- Failures can be diagnosed and resolved.

## Reference Solutions

Reference solutions are provided to help students understand correct implementations and review their work.

Attempt each project independently before consulting its solution.

There may be multiple valid approaches to solving a problem. What matters is that your implementation meets the requirements and that you understand the decisions you made.

## Next Steps

After completing these projects, you should be comfortable working with Docker in a local development environment and understand the fundamentals of operating containerized applications.

You can continue learning by exploring Kubernetes, container orchestration, CI/CD pipelines, and container security.

Return to the [DOC-301 course](https://devopsforger.com/courses/doc-301) to review lessons or revisit concepts you need to strengthen.