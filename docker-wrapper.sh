#!/bin/bash

# Full path to the real Docker CLI
DOCKER_CLI="/usr/bin/docker"

# Full path to the Kaniko executor
KANIKO_EXECUTOR="/kaniko/executor"

# Full path to Crane
CRANE_CLI="/usr/local/bin/crane"

# Temporary tarball for Kaniko image tar
IMAGE_TARBALL="/kaniko/image.tar"

# Ensure required tools exist
if [ ! -x "$KANIKO_EXECUTOR" ]; then
  echo "Kaniko executor not found at $KANIKO_EXECUTOR. Please check the path."
  exit 1
fi

if [ ! -x "$CRANE_CLI" ]; then
  echo "Crane not found at $CRANE_CLI. Please check the path."
  exit 1
fi

# Handle Docker-like commands
case "$1" in
  build)
    # Parse `docker build` arguments
    shift
    while [[ $# -gt 0 ]]; do
      case $1 in
        -t|--tag)
          IMAGE_TAG="$2"
          shift 2
          ;;
        -f|--file)
          DOCKERFILE_PATH="$2"
          shift 2
          ;;
        --)
          shift
          break
          ;;
        *)
          CONTEXT="$1"
          shift
          ;;
      esac
    done

    # Set defaults if not provided
    DOCKERFILE_PATH="${DOCKERFILE_PATH:-Dockerfile}"
    CONTEXT="${CONTEXT:-.}"
    IMAGE_TAG="${IMAGE_TAG:-kaniko:latest}"

    # Kaniko build command (no cache, extract image to a tarball)
    echo "Building image with Kaniko..."
    $KANIKO_EXECUTOR \
      --context "$CONTEXT" \
      --dockerfile "$DOCKERFILE_PATH" \
      --destination "$IMAGE_TAG" \
      --tarPath "$IMAGE_TARBALL"

    if [[ $? -eq 0 ]]; then
      echo "Image built successfully and saved to $IMAGE_TARBALL."
    else
      echo "Kaniko build failed."
      exit 1
    fi
    ;;
  
  push)
    # Parse `docker push` arguments
    shift
    IMAGE_TAG="$1"

    if [ -z "$IMAGE_TAG" ]; then
      echo "Error: Image tag is required for docker push."
      exit 1
    fi

    # Use Crane to push the tarball
    echo "Pushing image with Crane..."
    $CRANE_CLI push "$IMAGE_TARBALL" "$IMAGE_TAG"

    if [[ $? -eq 0 ]]; then
      echo "Image pushed successfully to $IMAGE_TAG."
    else
      echo "Crane push failed."
      exit 1
    fi
    ;;
  
  *)
    # Pass other commands to the real Docker CLI
    $DOCKER_CLI "$@"
    ;;
esac
