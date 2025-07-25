# LLM Agent Sandbox

A secure Docker-based sandbox for running CLI-based LLM agents with complete isolation from the host system. Features file system isolation, network whitelisting via DNS proxy, and granular path restrictions.

## Quick Start

### Prerequisites

- Docker Desktop or Docker Engine
- Bash shell

### 1. Setup

```bash
# Clone and navigate to sandbox
git clone <repo-url> llm-sandbox
cd llm-sandbox

# Build Docker images
docker build -t coder-sandbox -f Dockerfile.agent . --build-arg USER_ID=$(id -u)
docker build -t dns-proxy -f Dockerfile.dns .

# Make scripts executable
chmod +x run-agent.sh test_sandbox.sh
```

### 2. Basic Usage

```bash
# Navigate to your project directory
cd /path/to/your/project

# Run commands in sandbox
/path/to/llm-sandbox/run-agent.sh <command>

# Examples
/path/to/llm-sandbox/run-agent.sh ls -la
/path/to/llm-sandbox/run-agent.sh npm install express
/path/to/llm-sandbox/run-agent.sh python script.py
/path/to/llm-sandbox/run-agent.sh bash  # Interactive shell
```

### 3. Test Security

```bash
cd llm-sandbox
./test_sandbox.sh  # Runs 5 security validation tests
```

## Key Features

- 🔒 **File System Isolation**: Only accesses your current project directory
- 🌐 **Network Whitelisting**: DNS-based filtering for approved domains only
- 📝 **Request Logging**: All network attempts logged with timestamps
- ⚡ **Ephemeral**: Containers destroyed after each run
- 🛡️ **Non-root Execution**: Proper permission mapping with host user ID
- 🚫 **Path Restrictions**: Block specific files/folders within project

## Configuration

### Network Whitelist

Edit `whitelist.txt` to control domain access:

```txt
# Package managers
registry.npmjs.org
pypi.org

# Anthropic Claude API
api.anthropic.com
claude.ai
statsig.anthropic.com
ingest.us.sentry.io
console.anthropic.com

# Add your domains here
api.example.com
```

After editing, rebuild: `docker build -t dns-proxy -f Dockerfile.dns .`

### Path Restrictions

Restrict access to sensitive files within your project:

**Option 1: File-based (Recommended)**

```bash
# Copy restriction config to your project
cp /path/to/llm-sandbox/restricted-paths.txt /path/to/your/project/
cd /path/to/your/project
/path/to/llm-sandbox/run-agent.sh ls -la  # Restrictions applied
```

**Option 2: Environment Variable**

```bash
cd /path/to/your/project
RESTRICTED_PATHS="secrets,config.json,private" /path/to/llm-sandbox/run-agent.sh command
```

**Example `restricted-paths.txt`:**

```txt
# Block these paths in your project
secrets
private
.env
config.json
api-keys.txt
```

### Environment Variables

```bash
# Use different project directory
CODE_DIR=/other/project /path/to/llm-sandbox/run-agent.sh command

# Custom image names
SANDBOX_IMAGE=my-sandbox /path/to/llm-sandbox/run-agent.sh command

# Custom network name
RESTRICTED_NETWORK=my-net /path/to/llm-sandbox/run-agent.sh command
```

## Development Workflows

### Claude Code Integration

Claude Code is pre-installed globally in the sandbox:

```bash
cd /path/to/your/project

# Start Claude Code interactive session
/path/to/llm-sandbox/run-agent.sh claude

# Check version
/path/to/llm-sandbox/run-agent.sh claude --version
```

Claude Code will be using your host credentials, so ensure you have them set up
in your environment.

### Custom Tool Installation

Create custom Dockerfile for additional tools:

```dockerfile
# Dockerfile.custom
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y nodejs npm python3-pip curl your-tools
# ... rest follows same pattern as Dockerfile.agent
```

Build and use:

```bash
docker build -t custom-sandbox -f Dockerfile.custom . --build-arg USER_ID=$(id -u)
SANDBOX_IMAGE=custom-sandbox /path/to/llm-sandbox/run-agent.sh your-command
```

## Security Model

The sandbox implements defense-in-depth with three layers:

1. **Container Isolation**: Agent runs in separate container, only accesses mounted project directory
2. **Network Isolation**: Custom Docker network with DNS proxy - only whitelisted domains resolve
3. **Path Restrictions**: Within project directory, specific files/folders can be blocked via permission removal

## Monitoring

### View Network Activity

```bash
# See real-time DNS requests
docker logs -f dns-proxy

# Example output:
# [2025-07-24T11:32:58] ALLOWED: pypi.org
# [2025-07-24T11:33:45] BLOCKED: malicious-site.com
```

### Container Status

```bash
docker ps                    # Running containers
docker logs <container-id>   # Container logs
```

## Project Structure

```
llm-sandbox/
├── Dockerfile.agent        # Agent container (Ubuntu + Node.js/Python/curl)
├── Dockerfile.dns          # DNS proxy container
├── run-agent.sh            # Main execution script
├── init-restricted.sh      # Container entrypoint with path restrictions
├── dns_proxy.py            # DNS filtering server
├── whitelist.txt           # Allowed domains
├── restricted-paths.txt    # Path restriction template
├── test_sandbox.sh         # Security validation tests
└── README.md
```

## Troubleshooting

**Docker daemon not running**

```bash
# macOS: Open Docker Desktop
# Linux: sudo systemctl start docker
```

**Network conflicts**

```bash
docker network rm agent-net
docker rm -f dns-proxy
```

**Permission errors**

```bash
chmod +x run-agent.sh test_sandbox.sh
```

**DNS resolution fails**

```bash
docker build -t dns-proxy -f Dockerfile.dns .  # Rebuild DNS proxy
```

## Testing

Run the comprehensive test suite:

```bash
./test_sandbox.sh
```

**Test Coverage:**

- File access isolation (outside project directory)
- Network access to whitelisted domains
- Network blocking of non-whitelisted domains
- Path restrictions (file-based and environment variable)
- Container lifecycle management

## License

Provided as-is for educational and security research purposes. Use responsibly and in accordance with your organization's security policies.

---

**⚠️ Security Notice**: Designed for development and testing. Review and validate security configuration before production use.
