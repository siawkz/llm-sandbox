#!/bin/bash

set -e

echo "Starting sandbox security tests..."

# Build the Docker images first
echo "Building Docker images..."
docker build -t coder-sandbox -f Dockerfile.agent .
docker build -t dns-proxy -f Dockerfile.dns .

# Clean up any existing containers and networks
echo "Cleaning up existing containers and networks..."
docker rm -f dns-proxy 2>/dev/null || true
docker network rm agent-net 2>/dev/null || true

# Test setup - clean up first, then create fresh (no permission issues with bind mounts)
rm -rf src 2>/dev/null || true
mkdir -p src src/secrets src/private src/public
echo "test content" > src/test.txt
echo "public data" > src/public/data.txt
echo "private data" > src/private/config.txt
echo "secret key=12345" > src/secrets/key.txt
echo "sensitive config" > src/config.json
echo "secret content" > secret.txt

echo ""
echo "=== Test Case 1: File Access Isolation ==="
echo "Testing that agent cannot access files outside mounted directory..."

if ./run-agent.sh ls /home/agent/app/secret.txt 2>/dev/null; then
    echo "FAIL: Agent can access files outside mounted directory"
    exit 1
else
    echo "PASS: Agent cannot access files outside mounted directory"
fi

echo ""
echo "=== Test Case 2: Network Access (Allowed) ==="
echo "Testing access to whitelisted domain..."

if ./run-agent.sh curl -I --connect-timeout 10 https://pypi.org 2>/dev/null; then
    echo "PASS: Agent can access whitelisted domains"
else
    echo "FAIL: Agent cannot access whitelisted domains"
    exit 1
fi

echo ""
echo "=== Test Case 3: Network Access (Blocked) ==="
echo "Testing access to non-whitelisted domain..."

if ./run-agent.sh curl -I --connect-timeout 10 https://example.com 2>/dev/null; then
    echo "FAIL: Agent can access non-whitelisted domains"
    exit 1
else
    echo "PASS: Agent cannot access non-whitelisted domains"
fi

echo ""
echo "=== Test Case 4: Subfolder Restrictions (File-based) ==="
echo "Testing subfolder restrictions using restricted-paths.txt..."

# Create a copy of the restricted-paths.txt in src directory for the test
cp restricted-paths.txt src/

# Test that restricted paths show restricted permissions (bind mounts show as d---------  with root owner)
./run-agent.sh ls -la 2>/dev/null | grep '^d---------.*root.*root.*secrets'>/dev/null
SECRETS_RESTRICTED=$?
./run-agent.sh ls -la 2>/dev/null | grep '^d---------.*root.*root.*private'>/dev/null  
PRIVATE_RESTRICTED=$?
if [ $SECRETS_RESTRICTED -eq 0 ] && [ $PRIVATE_RESTRICTED -eq 0 ]; then
    echo "PASS: Restricted directories show no permissions (d--------- root root)"
else
    echo "FAIL: Restricted directories do not show restricted permissions"
    # Show actual output for debugging
    echo "Debug output:"
    ./run-agent.sh ls -la 2>/dev/null | grep -E '(secrets|private)'
    exit 1
fi

# Test that public directory is still accessible
if ./run-agent.sh cat public/data.txt 2>/dev/null | grep -q "public data"; then
    echo "PASS: Non-restricted directories are still accessible"
else
    echo "FAIL: Non-restricted directories are not accessible"
    exit 1
fi

echo ""
echo "=== Test Case 5: Subfolder Restrictions (Environment Variable) ==="
echo "Testing subfolder restrictions using environment variable..."

# Test with environment variable override (temporarily remove file-based config)
mv src/restricted-paths.txt src/restricted-paths.txt.bak
RESTRICTED_PATHS="config.json" ./run-agent.sh ls -la config.json 2>/dev/null | grep '^----------.*root.*root.*config.json' >/dev/null
CONFIG_RESTRICTED=$?
mv src/restricted-paths.txt.bak src/restricted-paths.txt
if [ $CONFIG_RESTRICTED -eq 0 ]; then
    echo "PASS: Environment variable restrictions work"
else
    echo "FAIL: Environment variable restrictions do not work"
    # Show actual output for debugging
    echo "Debug output:"
    RESTRICTED_PATHS="config.json" ./run-agent.sh ls -la config.json 2>/dev/null
    exit 1
fi

# Cleanup
echo ""
echo "Cleaning up test files..."
rm -f secret.txt
rm -rf src  # Can now delete entire src directory without permission issues

# Stop containers and remove network
docker rm -f dns-proxy 2>/dev/null || true
docker network rm agent-net 2>/dev/null || true

echo ""
echo "All tests passed! Sandbox security is working correctly."