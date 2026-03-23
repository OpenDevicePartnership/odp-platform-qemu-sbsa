REPO_ROOT_IN_HOST := $(shell realpath $(dir $(lastword $(MAKEFILE_LIST))))
REPO_ROOT_IN_DEVCONTAINER := /workspaces/$(shell basename $(REPO_ROOT_IN_HOST))
DEVCONTAINER_WORKSPACE_FLAGS := \
	--workspace-folder $(REPO_ROOT_IN_HOST) \
	--remote-env GIT_COMMITTER_NAME=vscode \
	--remote-env GIT_COMMITTER_EMAIL=vscode@example.com
DEVCONTAINER_FILES := \
	$(REPO_ROOT_IN_HOST)/.devcontainer/devcontainer.json \
	$(REPO_ROOT_IN_HOST)/.devcontainer/Dockerfile
DEVCONTAINER_STAMP := $(REPO_ROOT_IN_HOST)/.devcontainer-up.stamp
ifeq ($(IN_DEVCONTAINER),1)
BUILDER_IMAGE_DEPS :=
else
BUILDER_IMAGE_DEPS := $(DEVCONTAINER_STAMP)
endif

# ------------------------------------------------------------
# CI log grouping (GitHub Actions foldable sections)
# ------------------------------------------------------------
ifeq ($(CI),true)
GROUP = @echo '::group::$(1)'
ENDGROUP = @echo '::endgroup::'
else
GROUP =
ENDGROUP =
endif

# ------------------------------------------------------------
# Devcontainer command variables
# ------------------------------------------------------------
ifeq ($(IN_DEVCONTAINER),1)
DOCKER_COMMAND_PREFIX :=
REPO_ROOT := $(REPO_ROOT_IN_HOST)
else
DOCKER_COMMAND_PREFIX := devcontainer exec $(DEVCONTAINER_WORKSPACE_FLAGS)
REPO_ROOT := $(REPO_ROOT_IN_DEVCONTAINER)
endif


$(DEVCONTAINER_STAMP): $(DEVCONTAINER_FILES)
	@echo "=== Ensuring devcontainer is up to date ==="
	devcontainer up $(DEVCONTAINER_WORKSPACE_FLAGS)
	@touch "$@"


# ------------------------------------------------------------
# Ensure the devcontainer is available for building components
# ------------------------------------------------------------
.PHONY: builder-image
builder-image: $(BUILDER_IMAGE_DEPS)
ifeq ($(IN_DEVCONTAINER),1)
	@echo "=== Skipping devcontainer startup (running inside devcontainer) ==="
else
	@if ! devcontainer exec $(DEVCONTAINER_WORKSPACE_FLAGS) true >/dev/null 2>&1; then \
		echo "=== Devcontainer is not running, bringing it up ==="; \
		devcontainer up $(DEVCONTAINER_WORKSPACE_FLAGS); \
		touch "$(DEVCONTAINER_STAMP)"; \
	else \
		echo "=== Devcontainer already up to date ==="; \
	fi
endif
