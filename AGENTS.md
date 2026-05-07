# AGENTS.md: sshitmaids

## Overview

sshitmaids is a simple docker ssh mitm server to keep private keys private from
AI agent clients.

## Build & Test

Project uses a makefile.  "make" to build, "make compose-up" to run.  Coding
agents running inside a docker container may not have access to this.

## Structure

- volumes: .gitignored, contains the docker-bound volumes
- container: contains the Dockerfile and .sh files that will run on the container (eg entrypoint.sh)
- build: contains .sh files that will run at build-time.

## Style

Bash files are preferred. Brevity. Use `echo` for section headers
instead of comments.