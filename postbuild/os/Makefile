# OS image build targets for the ODP QEMU `virt` Platform.
#
# SPDX-License-Identifier: MIT
#

include ../../Common.mk

# ------------------------------------------------------------
# Workspace setup
# ------------------------------------------------------------
WORKSPACE ?= $(CURDIR)
OS_IMAGE_OUTPUT := build/winvos.qcow2
OS_IMAGE_INPUT := prebuilt/ValidationOS.vhdx
OS_IMAGE_WORKFLOW ?= build-os.yml
OS_IMAGE_ARTIFACT ?= os-image
OS_IMAGE_ARTIFACT_FILE ?= os-image.vhdx
OS_IMAGE_REPO ?=

BIOS_FLASH0 := ../../$(BIOS_FV_DIR)/SECURE_FLASH0.fd
BIOS_EFI    := ../../$(BIOS_FV_DIR)/QEMU_EFI.fd
BIOS_OUTPUTS := $(BIOS_FLASH0) $(BIOS_EFI)

# ------------------------------------------------------------
# Throw error if the BIOS images are not present
# ------------------------------------------------------------
$(BIOS_OUTPUTS):
	@echo "Please build the BIOS images by running 'make all' in the root directory before building the OS image."
	@exit 1

# ------------------------------------------------------------
# Download the input image from GitHub Actions if needed
# ------------------------------------------------------------
$(OS_IMAGE_INPUT):
	@set -eu; \
	if ! command -v gh >/dev/null 2>&1; then \
		echo "GitHub CLI (gh) is required to fetch $(OS_IMAGE_INPUT)."; \
		exit 1; \
	fi; \
	if ! gh auth status >/dev/null 2>&1; then \
		echo "GitHub CLI is not authenticated. Run 'gh auth login' and retry."; \
		exit 1; \
	fi; \
	repo="$(OS_IMAGE_REPO)"; \
	if [ -z "$$repo" ]; then \
		remote_url="$$(git config --get remote.origin.url || true)"; \
		if [ -z "$$remote_url" ]; then \
			echo "Could not determine GitHub repository from git remote."; \
			echo "Set OS_IMAGE_REPO=<owner>/<repo> and retry."; \
			exit 1; \
		fi; \
		repo="$$(printf '%s\n' "$$remote_url" | sed -E 's#^https://github.com/([^/]+/[^/.]+)(\.git)?$$#\1#; s#^git@github.com:([^/]+/[^/.]+)(\.git)?$$#\1#')"; \
		if [ "$$repo" = "$$remote_url" ]; then \
			echo "Unsupported remote URL '$$remote_url' for GitHub Actions artifact fetch."; \
			echo "Set OS_IMAGE_REPO=<owner>/<repo> and retry."; \
			exit 1; \
		fi; \
	fi; \
	branch="$$(git rev-parse --abbrev-ref HEAD)"; \
	ref="$$branch"; \
	branch_filter=1; \
	if [ "$$branch" = "HEAD" ]; then \
		ref="$$(git rev-parse HEAD)"; \
		branch_filter=0; \
	fi; \
	gh_user="$$(GH_FORCE_TTY=0 gh api user --jq .login)"; \
	if [ "$$branch_filter" -eq 1 ]; then \
		before_run_id="$$(GH_FORCE_TTY=0 gh run list --repo "$$repo" --workflow "$(OS_IMAGE_WORKFLOW)" --event workflow_dispatch --user "$$gh_user" --branch "$$branch" --limit 1 --json databaseId --jq '.[0].databaseId')"; \
	else \
		before_run_id="$$(GH_FORCE_TTY=0 gh run list --repo "$$repo" --workflow "$(OS_IMAGE_WORKFLOW)" --event workflow_dispatch --user "$$gh_user" --limit 1 --json databaseId --jq '.[0].databaseId')"; \
	fi; \
	echo "$(OS_IMAGE_INPUT) not found. Triggering workflow '$(OS_IMAGE_WORKFLOW)' in '$$repo' on ref '$$ref'..."; \
	GH_FORCE_TTY=0 gh workflow run "$(OS_IMAGE_WORKFLOW)" --repo "$$repo" --ref "$$ref"; \
	run_id=""; \
	for _ in 1 2 3 4 5 6 7 8 9 10; do \
		if [ "$$branch_filter" -eq 1 ]; then \
			run_id="$$(GH_FORCE_TTY=0 gh run list --repo "$$repo" --workflow "$(OS_IMAGE_WORKFLOW)" --event workflow_dispatch --user "$$gh_user" --branch "$$branch" --limit 1 --json databaseId --jq '.[0].databaseId')"; \
		else \
			run_id="$$(GH_FORCE_TTY=0 gh run list --repo "$$repo" --workflow "$(OS_IMAGE_WORKFLOW)" --event workflow_dispatch --user "$$gh_user" --limit 1 --json databaseId --jq '.[0].databaseId')"; \
		fi; \
		if [ -n "$$run_id" ] && [ "$$run_id" != "null" ] && [ "$$run_id" != "$$before_run_id" ]; then \
			break; \
		fi; \
		sleep 3; \
	done; \
	if [ -z "$$run_id" ] || [ "$$run_id" = "null" ]; then \
		echo "Could not find dispatched run for $(OS_IMAGE_WORKFLOW)."; \
		exit 1; \
	fi; \
	echo "Waiting for workflow run $$run_id in '$$repo' to complete..."; \
	GH_FORCE_TTY=0 gh run watch "$$run_id" --repo "$$repo" --exit-status; \
	mkdir -p prebuilt; \
	rm -f prebuilt/$(OS_IMAGE_ARTIFACT_FILE) "$(OS_IMAGE_INPUT)"; \
	GH_FORCE_TTY=0 gh run download "$$run_id" --repo "$$repo" --name "$(OS_IMAGE_ARTIFACT)" --dir prebuilt; \
	if [ ! -f prebuilt/$(OS_IMAGE_ARTIFACT_FILE) ]; then \
		echo "Expected artifact file prebuilt/$(OS_IMAGE_ARTIFACT_FILE) was not downloaded."; \
		exit 1; \
	fi; \
	mv prebuilt/$(OS_IMAGE_ARTIFACT_FILE) "$(OS_IMAGE_INPUT)"; \
	echo "Downloaded $(OS_IMAGE_INPUT)."

# ------------------------------------------------------------
# Generate qcow2 image from VHDX image
# ------------------------------------------------------------
$(OS_IMAGE_OUTPUT): $(OS_IMAGE_INPUT)
	mkdir -p build
	qemu-img convert -f vhdx -O qcow2 $< $(OS_IMAGE_OUTPUT)

qcow2: $(OS_IMAGE_OUTPUT)

# ------------------------------------------------------------
# Clean everything
# ------------------------------------------------------------
clean:
	@echo "=== Cleaning OS image build artifacts ==="
	rm -rf build

