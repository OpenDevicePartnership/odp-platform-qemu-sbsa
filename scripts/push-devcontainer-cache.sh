#!/usr/bin/env bash
# push-devcontainer-cache.sh
#
# Rebuilds and pushes the devcontainer image cache to GHCR using the
# devcontainer CLI. This ensures the pushed cache uses the same Dockerfile
# wrapper (Dockerfile-with-features) and stage names that the devcontainers/ci
# GitHub Action uses, so CI gets cache hits.
#
# Two-phase approach:
#   1. `devcontainer build --output type=cacheonly` generates the wrapper
#      Dockerfile and populates the local BuildKit cache.
#   2. `docker buildx build --push` rebuilds from local cache, pushes :latest
#      (with inline cache metadata) and writes registry cache to :cache
#      (mode=max, all intermediate layers).
#
# CRITICAL: Step 2 must pass --build-arg BUILDKIT_INLINE_CACHE=1 to match
# what devcontainers/ci does in CI. Without this, the pushed image lacks
# inline cache metadata, and CI's cache chain breaks at COPY instructions.
#
# Prerequisites:
#   - npm i -g @devcontainers/cli
#   - docker login ghcr.io (e.g. via: gh auth token | docker login ghcr.io -u <user> --password-stdin)
#   - docker buildx (with a builder that supports multi-platform)
#
# Usage:
#   ./scripts/push-devcontainer-cache.sh [IMAGE_NAME]
#
# IMAGE_NAME defaults to ghcr.io/<gh-user>/odp-platform-qemu-sbsa-devcontainer.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Resolve image name: argument > GH_USER env > git config
if [[ -n "${1:-}" ]]; then
    IMAGE_NAME="$1"
else
    GH_USER="${GH_USER:-$(gh api user --jq .login 2>/dev/null || git config github.user || echo "")}"
    if [[ -z "$GH_USER" ]]; then
        echo "ERROR: Could not determine GitHub username." >&2
        echo "Set GH_USER env var, pass IMAGE_NAME as argument, or run 'gh auth login'." >&2
        exit 1
    fi
    # GHCR requires lowercase
    GH_USER="$(echo "$GH_USER" | tr '[:upper:]' '[:lower:]')"
    IMAGE_NAME="ghcr.io/${GH_USER}/odp-platform-qemu-sbsa-devcontainer"
fi

echo "==> Image name: ${IMAGE_NAME}"
echo "==> Workspace:  ${REPO_ROOT}"

# Step 1: Run devcontainer build to generate the Dockerfile-with-features
# wrapper and populate local BuildKit cache. Output is cache-only (no push).
echo "==> Generating Dockerfile-with-features via devcontainer build..."
devcontainer build \
    --workspace-folder "$REPO_ROOT" \
    --image-name "$IMAGE_NAME" \
    --platform linux/amd64,linux/arm64 \
    --output "type=cacheonly" \
    --log-level debug 2>&1 | tee /tmp/devcontainer-build.log

# Extract the Dockerfile-with-features path from the debug log.
DOCKERFILE_WITH_FEATURES=$(
    awk '{
        for (i = 1; i < NF; i++) {
            if ($i == "-f" && $(i+1) ~ /Dockerfile-with-features$/) {
                print $(i+1);
                exit;
            }
        }
    }' /tmp/devcontainer-build.log
)
if [[ -z "$DOCKERFILE_WITH_FEATURES" || ! -f "$DOCKERFILE_WITH_FEATURES" ]]; then
    echo "ERROR: Could not find generated Dockerfile-with-features." >&2
    echo "Check /tmp/devcontainer-build.log for details." >&2
    exit 1
fi
echo "==> Found wrapper: $DOCKERFILE_WITH_FEATURES"

# Step 2: Push the image and registry cache.
#
# Uses the wrapper Dockerfile from step 1, rebuilds from local BuildKit cache
# (populated by step 1), and pushes:
#   - :latest image with BUILDKIT_INLINE_CACHE=1 (embeds inline cache metadata)
#   - :cache registry cache with mode=max (stores ALL intermediate layers)
#
# CI reads cache from both sources:
#   - Bare image refs (inline cache from :latest) — fast, works for all layers
#   - type=registry,ref=:cache — fallback with full intermediate layer coverage
echo "==> Building and pushing with inline + registry cache..."
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    --target dev_containers_target_stage \
    --build-arg "_DEV_CONTAINERS_BASE_IMAGE=dev_container_auto_added_stage_label" \
    --build-arg "BUILDKIT_INLINE_CACHE=1" \
    --cache-from "type=registry,ref=${IMAGE_NAME}:cache" \
    --cache-from "type=registry,ref=ghcr.io/opendevicepartnership/odp-platform-qemu-sbsa-devcontainer:cache" \
    --cache-to "type=registry,ref=${IMAGE_NAME}:cache,mode=max" \
    -t "${IMAGE_NAME}:latest" \
    -f "$DOCKERFILE_WITH_FEATURES" \
    --push \
    --progress=plain \
    "$REPO_ROOT"

echo ""
echo "==> Done. Pushed ${IMAGE_NAME}:latest (with inline cache) and"
echo "    registry cache to ${IMAGE_NAME}:cache (mode=max)."
echo "    CI will read cache via cacheFrom in build.yml / devcontainer.json."
