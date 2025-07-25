#!/bin/bash

set -e

CODE_DIR="${CODE_DIR:-$(pwd)}"
SANDBOX_IMAGE="${SANDBOX_IMAGE:-coder-sandbox}"
RESTRICTED_NETWORK="${RESTRICTED_NETWORK:-agent-net}"

if [ $# -eq 0 ]; then
	echo "Error: No command provided for the agent"
	echo "Usage: $0 <command> [args...]"
	exit 1
fi

# Create network if it doesn't exist
if ! docker network ls | grep -q "$RESTRICTED_NETWORK"; then
	docker network create "$RESTRICTED_NETWORK"
fi

# Start DNS proxy if not running
if ! docker ps | grep -q dns-proxy; then
	docker run -d --name dns-proxy \
		--network "$RESTRICTED_NETWORK" \
		dns-proxy
fi

# Get DNS proxy IP dynamically
DNS_PROXY_IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dns-proxy)

# Verify CODE_DIR exists
if [ ! -d "$CODE_DIR" ]; then
	echo "Error: Directory '$CODE_DIR' does not exist"
	echo "Please ensure you're running from your project directory or set CODE_DIR correctly"
	exit 1
fi

# Validate configuration files if validation script exists
if [ -x "./validate_config.sh" ]; then
	./validate_config.sh 2>/dev/null || echo "⚠️  Configuration validation failed. Run ./validate_config.sh for details."
fi

# Detect if we need interactive mode (TTY allocation)
DOCKER_FLAGS="--rm"
if [ -t 0 ] && [ -t 1 ]; then
	# Both stdin and stdout are terminals, enable interactive mode
	DOCKER_FLAGS="$DOCKER_FLAGS -it"
fi

# Run the agent container (starts as root, switches to agent user after restrictions)
# Requires --privileged for bind mounts, but container is still isolated via network/filesystem
docker run $DOCKER_FLAGS \
	--privileged \
	--network "$RESTRICTED_NETWORK" \
	--dns "$DNS_PROXY_IP" \
	-e TERM=xterm-256color \
	-e RESTRICTED_PATHS="${RESTRICTED_PATHS:-}" \
	-v "$CODE_DIR:/home/agent/app" \
	-v "$HOME/.claude:/home/agent/.claude:rw" \
	-v "$HOME/.claude.json:/home/agent/.claude.json:rw" \
	"$SANDBOX_IMAGE" \
	"$@"
