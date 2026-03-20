REPO_ROOT_IN_HOST := $(shell realpath $(dir $(lastword $(MAKEFILE_LIST))))
REPO_ROOT_IN_DEVCONTAINER := /workspaces/$(shell basename $(REPO_ROOT_IN_HOST))

# ------------------------------------------------------------
# Builder image variables
# ------------------------------------------------------------
BUILDER_IMAGE := odp-platform-qemu-sbsa-builder
DOCKER_COMMON_FLAGS = \
	--user vscode:vscode \
	--workdir $(REPO_ROOT_IN_DEVCONTAINER) \
	--mount type=bind,source=$(shell dirname $(REPO_ROOT_IN_HOST)),target=/workspaces \
	--env GIT_COMMITTER_NAME=vscode \
	--env GIT_COMMITTER_EMAIL=vscode@example.com
ifeq ($(IN_DEVCONTAINER),1)
DOCKER_COMMAND_PREFIX :=
REPO_ROOT := $(REPO_ROOT_IN_HOST)
else
DOCKER_TTY_FLAG := $(shell [ -t 0 ] && echo "-it" || echo "-i")
DOCKER_COMMAND_PREFIX := docker run --rm $(DOCKER_TTY_FLAG) $(DOCKER_COMMON_FLAGS) $(BUILDER_IMAGE)
REPO_ROOT := $(REPO_ROOT_IN_DEVCONTAINER)
endif


# ------------------------------------------------------------
# Build Docker Image for building components
# ------------------------------------------------------------
.PHONY: builder-image
builder-image:
ifeq ($(IN_DEVCONTAINER),1)
	@echo "=== Skipping Docker image build (running inside devcontainer) ==="
else
	@echo "=== Building Docker Image ==="
	docker buildx build \
		--cache-from type=registry,ref=ghcr.io/dymk/odp-platform-qemu-sbsa-devcontainer:cache \
		--cache-from ghcr.io/dymk/odp-platform-qemu-sbsa-devcontainer:latest \
		--cache-from type=registry,ref=ghcr.io/opendevicepartnership/odp-platform-qemu-sbsa-devcontainer:cache \
		--cache-from ghcr.io/opendevicepartnership/odp-platform-qemu-sbsa-devcontainer:latest \
		-t $(BUILDER_IMAGE) \
		-f $(REPO_ROOT_IN_HOST)/.devcontainer/Dockerfile \
		--load \
		$(REPO_ROOT_IN_HOST)
endif
