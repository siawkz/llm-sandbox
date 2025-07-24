#!/bin/bash

set -e

CODE_DIR="${CODE_DIR:-src}"
SANDBOX_IMAGE="${SANDBOX_IMAGE:-coder-sandbox}"
RESTRICTED_NETWORK="${RESTRICTED_NETWORK:-agent-net}"

if [ $# -eq 0 ]; then
    echo "Error: No command provided for the agent"
    echo "Usage: $0 <command> [args...]"
    exit 1
fi

# Create network if it doesn't exist
if ! docker network ls | grep -q "$RESTRICTED_NETWORK"; then
    docker network create --subnet=172.18.0.0/16 "$RESTRICTED_NETWORK"
fi

# Start DNS proxy if not running
if ! docker ps | grep -q dns-proxy; then
    docker run -d --name dns-proxy \
        --network "$RESTRICTED_NETWORK" \
        --ip 172.18.0.2 \
        dns-proxy
fi

# Create CODE_DIR if it doesn't exist
mkdir -p "$CODE_DIR"

# Build image with correct user ID if needed
if ! docker images "$SANDBOX_IMAGE" | grep -q "$SANDBOX_IMAGE"; then
    docker build --build-arg USER_ID="$(id -u)" -t "$SANDBOX_IMAGE" -f Dockerfile.agent .
fi

# Run the agent container (starts as root, switches to agent user after restrictions)
# Requires --privileged for bind mounts, but container is still isolated via network/filesystem
docker run --rm -i \
    --privileged \
    --network "$RESTRICTED_NETWORK" \
    --dns 172.18.0.2 \
    -e RESTRICTED_PATHS="${RESTRICTED_PATHS:-}" \
    -v "$(pwd)/$CODE_DIR:/home/agent/app" \
    -v "$HOME/.config/gcloud:/home/agent/.config/gcloud:ro" \
    "$SANDBOX_IMAGE" \
    "$@"