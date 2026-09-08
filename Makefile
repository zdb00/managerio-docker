SHELL := /bin/bash
VERSION := $(shell cat MANAGER_VERSION)
IMAGE ?= managerio-docker:local
.PHONY: build run stop logs test clean upstream-version
build:
	docker buildx build --load --build-arg MANAGER_VERSION=$(VERSION) -t $(IMAGE) .
run:
	MANAGER_IMAGE=$(IMAGE) docker compose up -d
stop:
	docker compose stop
logs:
	docker compose logs -f managerio
test:
	./scripts/smoke-test.sh $(IMAGE)
clean:
	docker compose down
upstream-version:
	./scripts/check-upstream.sh
