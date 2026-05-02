# Makefile for sshitmaids docker

.PHONY: help init-sshitmaids build compose-up compose-down clean
.DEFAULT_GOAL := build

# Use this project name for tagging/pushing images
PROJECT_NAME := sshitmaids
AGENT_IMAGE := $(PROJECT_NAME):latest
ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
# Load .env file if it exists
ifneq (,$(wildcard .env))
    include .env
    export
endif

help:
	@echo "usage: make [target]"

init-sshitmaids:
	@bash ./src/init-volumes.sh $(SSHITMAIDS_DEST_HOST)

build: init-sshitmaids
	docker compose build

# Start the full stack (ensures network and builds agent first)
compose-up: build
	@echo "Starting stack with docker compose"
	docker compose up -d

compose-down:
	docker compose down

clean: compose-down
	@echo "Removing agent local image (if present)"
	-@docker image rm $(AGENT_IMAGE) || true