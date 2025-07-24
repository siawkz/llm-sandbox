# LLM Agent Sandbox

A secure, ephemeral, and sandboxed environment for running CLI-based LLM agents using Docker. This project provides complete isolation from the host system while allowing controlled access to a designated code directory and whitelisted network domains.

## Features

- 🔒 **Complete File System Isolation**: Agents can only access files in the designated `src` directory
- 🌐 **Network Whitelisting**: DNS-based filtering allows only approved domains
- 📝 **Comprehensive Logging**: All network access attempts are logged with timestamps
- ⚡ **Ephemeral Containers**: Containers are automatically destroyed after each run
- 🛡️ **Security First**: Non-root user execution with proper permission mapping
- 🧪 **Automated Testing**: Built-in security validation tests

## Quick Start

### Prerequisites

- Docker Desktop or Docker Engine
- Bash shell

### 1. Build the Docker Images

```bash
# Build the agent sandbox image
docker build -t coder-sandbox -f Dockerfile.agent .

# Build the DNS proxy image
docker build -t dns-proxy -f Dockerfile.dns .
```

### 2. Run a Command in the Sandbox

```bash
# Make the script executable
chmod +x run-agent.sh

# Run a simple command
./run-agent.sh echo "Hello from sandbox!"

# Run interactive commands
./run-agent.sh bash
```

### 3. Test the Security Features

```bash
# Run the automated test suite
./test_sandbox.sh
```

## Usage Examples

### Basic Commands

```bash
# List files in the sandbox
./run-agent.sh ls -la

# Check available tools
./run-agent.sh which node npm python3 curl

# Create and edit files (only in src directory)
./run-agent.sh bash -c "echo 'console.log(\"Hello World\")' > app.js"
./run-agent.sh node app.js
```

### Network Access

```bash
# Access whitelisted domains (works)
./run-agent.sh curl -I https://pypi.org
./run-agent.sh curl -I https://registry.npmjs.org

# Access blocked domains (fails)
./run-agent.sh curl -I https://example.com
```

### Development Workflow

```bash
# Install npm packages (from whitelisted registry)
./run-agent.sh npm init -y
./run-agent.sh npm install express

# Install Python packages (from whitelisted PyPI)
./run-agent.sh pip install requests

# Run your application
./run-agent.sh node server.js
./run-agent.sh python app.py
```

### Running Claude CLI in the Sandbox

The sandbox fully supports running Claude CLI with proper security isolation:

```bash
# Install Claude CLI (one-time setup)
./run-agent.sh npm init -y
./run-agent.sh npm install @anthropic-ai/claude-code

# Run Claude CLI commands
./run-agent.sh ./node_modules/.bin/claude --help

# Use Claude CLI with prompts (requires API key setup)
./run-agent.sh ./node_modules/.bin/claude --print "Your prompt here"

# Interactive Claude CLI session
./run-agent.sh ./node_modules/.bin/claude
```

**Security Features with Claude CLI:**
- ✅ **Network Isolation**: Only whitelisted Anthropic domains are accessible
- ✅ **File Isolation**: Claude can only access files in the `src` directory
- ✅ **Credential Isolation**: Host authentication tokens are not accessible
- ✅ **DNS Monitoring**: All network requests are logged and filtered

### Subfolder Restrictions

For additional security within the working directory, you can restrict access to specific files and subdirectories:

#### File-Based Configuration (Recommended)

Create or edit `restricted-paths.txt` in your project root and copy it to the `src` directory:

```bash
# Copy the restriction config to your working directory
cp restricted-paths.txt src/

# Run agent with restrictions applied
./run-agent.sh ls -la
```

**Example `restricted-paths.txt`:**
```txt
# Restricted paths configuration
# One path per line - supports both files and directories
# Lines starting with # are comments and will be ignored

# Sensitive directories
secrets
private
.env.local

# Configuration files
config.json
api-keys.txt
.env

# Add your custom restrictions here
sensitive-data
internal-docs
```

#### Environment Variable Configuration

For dynamic restrictions, use the `RESTRICTED_PATHS` environment variable:

```bash
# Restrict specific paths using environment variable
RESTRICTED_PATHS="secrets,private,config.json" ./run-agent.sh ls -la

# Multiple paths (comma-separated)
RESTRICTED_PATHS="secrets,api-keys.txt,.env,private" ./run-agent.sh your-command
```

#### Testing Restrictions

```bash
# View which paths are restricted (they show d--------- or ----------)
./run-agent.sh ls -la

# Try to access restricted content (should fail)
./run-agent.sh cat secrets/api-key.txt

# Access allowed content (should work)
./run-agent.sh cat public/readme.txt
```

**Restriction Features:**
- 🚫 **Granular Control**: Block specific files or directories by name
- 📁 **Working Directory Preserved**: Agent can still access `package.json`, `node_modules`, etc.
- 🔍 **Visual Feedback**: Restricted paths show `----------` or `d---------` permissions
- ⚙️ **Container-Internal**: No changes to host file system permissions
- 📝 **Configuration Priority**: File-based config takes precedence over environment variables

## Configuration

### Environment Variables

You can customize the sandbox behavior using environment variables:

```bash
# Change the code directory (default: src)
CODE_DIR=my-code ./run-agent.sh ls

# Use different image names
SANDBOX_IMAGE=my-sandbox ./run-agent.sh echo "test"

# Use different network name
RESTRICTED_NETWORK=my-net ./run-agent.sh curl -I https://pypi.org
```

### Network Whitelist

Edit `whitelist.txt` to add or remove allowed domains:

```txt
# Essential domains for LLM agents
generativelanguage.googleapis.com
iam.googleapis.com
oauth2.googleapis.com

# Package managers
registry.npmjs.org
pypi.org

# Anthropic Claude API domains
api.anthropic.com
claude.ai
statsig.anthropic.com

# Add your custom domains here
api.example.com
cdn.example.com
```

After modifying the whitelist, rebuild the DNS proxy:

```bash
docker build -t dns-proxy -f Dockerfile.dns .
```

## Project Structure

```
llm-sandbox/
├── Dockerfile.agent        # Agent sandbox container definition
├── Dockerfile.dns          # DNS proxy container definition
├── run-agent.sh            # Main wrapper script
├── init-restricted.sh      # Container init script for path restrictions
├── dns_proxy.py            # DNS filtering server
├── whitelist.txt           # Allowed domains configuration
├── restricted-paths.txt    # Restricted paths configuration
├── test_sandbox.sh         # Security validation tests (includes subfolder tests)
└── README.md               # This file
```

## Security Features

### File System Isolation

- Only the `src` directory (or `CODE_DIR`) is mounted into the container
- The agent cannot access files outside this directory
- Host file permissions are preserved through user ID mapping

### Network Restrictions

- Custom Docker network with isolated DNS
- DNS proxy blocks all non-whitelisted domains
- All network attempts are logged with timestamps
- NXDOMAIN responses for blocked domains

### Container Security

- Non-root user execution (UID 1001)
- Ephemeral containers (`--rm` flag)
- No privileged access
- Read-only gcloud credentials mount

## Monitoring and Logging

### View DNS Proxy Logs

```bash
# See real-time network access attempts
docker logs -f dns-proxy
```

Example log output:
```
[2025-07-24T11:32:58.560342] DNS proxy started with 5 whitelisted domains
[2025-07-24T11:32:58.939237] ALLOWED: pypi.org
[2025-07-24T11:33:45.123456] BLOCKED: malicious-site.com
```

### Container Status

```bash
# Check running containers
docker ps

# View container logs
docker logs <container-id>
```

## Testing

The project includes comprehensive security tests:

```bash
./test_sandbox.sh
```

**Test Coverage:**
- ✅ File access isolation (outside working directory)
- ✅ Network access to whitelisted domains
- ✅ Network blocking of non-whitelisted domains
- ✅ Subfolder restrictions (file-based configuration)
- ✅ Subfolder restrictions (environment variable configuration)
- ✅ Container lifecycle management

## Troubleshooting

### Common Issues

**"Cannot connect to Docker daemon"**
```bash
# Start Docker Desktop or Docker service
# On macOS: Open Docker Desktop
# On Linux: sudo systemctl start docker
```

**"Network agent-net already exists"**
```bash
# Clean up existing network
docker network rm agent-net
```

**"Permission denied" errors**
```bash
# Ensure script is executable
chmod +x run-agent.sh test_sandbox.sh
```

**DNS resolution fails**
```bash
# Check if DNS proxy is running
docker ps | grep dns-proxy

# Rebuild DNS proxy if needed
docker build -t dns-proxy -f Dockerfile.dns .
```

### Debug Mode

For troubleshooting, you can run commands with verbose output:

```bash
# Enable Docker debug mode
DOCKER_BUILDKIT=0 ./run-agent.sh your-command

# Check DNS proxy status
docker exec dns-proxy ps aux
```

## Development

### Adding New Whitelisted Domains

1. Edit `whitelist.txt`
2. Rebuild DNS proxy: `docker build -t dns-proxy -f Dockerfile.dns .`
3. Test access: `./run-agent.sh curl -I https://new-domain.com`

### Configuring Path Restrictions

1. Edit `restricted-paths.txt` to add/remove restricted paths
2. Copy to working directory: `cp restricted-paths.txt src/`
3. Test restrictions: `./run-agent.sh ls -la`
4. Alternatively, use environment variable: `RESTRICTED_PATHS="path1,path2" ./run-agent.sh command`

### Customizing the Agent Environment

1. Edit `Dockerfile.agent` to add new tools or packages
2. Rebuild: `docker build -t coder-sandbox -f Dockerfile.agent .`
3. Test: `./run-agent.sh which your-new-tool`

### Extending Security Tests

Add new test cases to `test_sandbox.sh`:

```bash
echo "=== Test Case 4: Your Custom Test ==="
# Your test logic here
```

## License

This project is provided as-is for educational and security research purposes. Use responsibly and in accordance with your organization's security policies.

## Contributing

1. Test all changes with `./test_sandbox.sh`
2. Ensure security features remain intact
3. Update documentation for any new features
4. Verify cross-platform compatibility

---

**⚠️ Security Notice**: This sandbox is designed for development and testing purposes. Always review and validate the security configuration before using in production environments.
