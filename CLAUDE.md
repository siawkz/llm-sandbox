# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a secure Docker-based sandbox system for running CLI-based LLM agents with complete isolation from the host system. The architecture implements multiple layers of security: file system isolation, network whitelisting via DNS proxy, and granular path restrictions within the working directory.

## Core Architecture

The system consists of three main components that work together:

### 1. Agent Container (`Dockerfile.agent`)
- Ubuntu 24.04 base with Node.js, npm, Python, and curl
- Uses dynamic user ID mapping (`USER_ID` build arg) to match host permissions
- Runs `init-restricted.sh` as entrypoint (starts as root, switches to agent user after applying restrictions)
- Working directory: `/home/agent/app` (mounted from host's `src/` directory)

### 2. DNS Proxy Container (`Dockerfile.dns`)
- Python-based DNS server using `dnslib` that filters network access
- Reads whitelist from `/data/whitelist.txt` (copied during build)
- Runs on custom Docker network at fixed IP `172.18.0.2`
- Logs all DNS requests as ALLOWED/BLOCKED with timestamps

### 3. Restriction System (`init-restricted.sh`)
- Container entrypoint that applies file/directory restrictions before switching to agent user
- Reads restrictions from `restricted-paths.txt` (file-based, priority) or `RESTRICTED_PATHS` env var
- Uses `chmod 000` to remove all permissions from restricted paths
- Executes user command via `su agent -c`

## Key Commands

### Build and Setup
```bash
# Build both containers (run from project root)
docker build -t coder-sandbox -f Dockerfile.agent .
docker build -t dns-proxy -f Dockerfile.dns .

# Make scripts executable
chmod +x run-agent.sh test_sandbox.sh
```

### Running Commands in Sandbox
```bash
# Basic usage - run any command in isolated environment
./run-agent.sh <command>

# Examples
./run-agent.sh ls -la                    # List files in working directory
./run-agent.sh npm install express       # Install packages (from whitelisted registries)
./run-agent.sh python script.py          # Run Python scripts
./run-agent.sh bash                      # Interactive shell
```

### Testing
```bash
# Run comprehensive security test suite (5 test cases)
./test_sandbox.sh

# Test cases validate:
# 1. File access isolation (outside working directory)
# 2. Network access to whitelisted domains  
# 3. Network blocking of non-whitelisted domains
# 4. Subfolder restrictions (file-based configuration)
# 5. Subfolder restrictions (environment variable configuration)
```

### Configuration Management

#### Network Whitelist (requires rebuild)
```bash
# Edit allowed domains
vim whitelist.txt

# Rebuild DNS proxy after changes
docker build -t dns-proxy -f Dockerfile.dns .
```

#### Path Restrictions (no rebuild needed)
```bash
# File-based restrictions (recommended)
cp restricted-paths.txt src/
./run-agent.sh command

# Environment variable restrictions (dynamic)
RESTRICTED_PATHS="secrets,config.json,private" ./run-agent.sh command
```

### Monitoring and Debugging
```bash
# View DNS proxy logs (network access attempts)
docker logs dns-proxy

# View running containers
docker ps

# Clean up (removes containers and network)
docker rm -f dns-proxy
docker network rm agent-net
```

## Security Model

The sandbox implements defense-in-depth with three isolation layers:

1. **Container Isolation**: Agent runs in separate container, cannot access host filesystem except mounted `src/` directory
2. **Network Isolation**: Custom Docker network with DNS proxy filtering - only whitelisted domains resolve
3. **Path Restrictions**: Within working directory, specific files/folders can be made inaccessible via permission removal

## Environment Variables

- `CODE_DIR` (default: `src`) - Host directory to mount as working directory
- `SANDBOX_IMAGE` (default: `coder-sandbox`) - Agent container image name  
- `RESTRICTED_NETWORK` (default: `agent-net`) - Docker network name
- `RESTRICTED_PATHS` - Comma-separated list of paths to restrict (overridden by `restricted-paths.txt` if present)

## Important Implementation Details

- **User ID Mapping**: Agent container built with host user ID to prevent permission issues on mounted volumes
- **DNS Proxy Lifecycle**: `run-agent.sh` automatically starts DNS proxy container if not running
- **Network Architecture**: Containers communicate on isolated subnet `172.18.0.0/16`
- **Restriction Priority**: File-based `restricted-paths.txt` takes precedence over `RESTRICTED_PATHS` environment variable
- **Container Lifecycle**: Agent containers are ephemeral (`--rm` flag), DNS proxy persists between runs

## Development Workflow

When making changes to the system:

1. **DNS Changes**: Edit `whitelist.txt` → rebuild DNS image → test network access
2. **Agent Changes**: Edit `Dockerfile.agent` or `init-restricted.sh` → rebuild agent image → test functionality  
3. **Restriction Changes**: Edit `restricted-paths.txt` or use env vars → test immediately (no rebuild needed)
4. **Always run**: `./test_sandbox.sh` after changes to validate security model integrity

The system is designed to fail securely - if DNS proxy is unavailable, network access fails; if restrictions can't be applied, the container should not start.