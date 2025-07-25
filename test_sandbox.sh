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
rm -rf test_project 2>/dev/null || true
rm -f outside_secret.txt 2>/dev/null || true
mkdir -p test_project test_project/secrets test_project/private test_project/public
echo "test content" >test_project/test.txt
echo "public data" >test_project/public/data.txt
echo "private data" >test_project/private/config.txt
echo "secret key=12345" >test_project/secrets/key.txt
echo "sensitive config" >test_project/config.json
echo "secret content outside project" >outside_secret.txt

echo ""
echo "=== Test Case 1: File Access Isolation ==="
echo "Testing that agent cannot access files outside mounted directory..."

# Test from inside the project directory - agent should NOT see files outside
cd test_project
if ../run-agent.sh ls ../outside_secret.txt 2>/dev/null; then
	echo "FAIL: Agent can access files outside mounted directory"
	cd ..
	exit 1
else
	echo "PASS: Agent cannot access files outside mounted directory"
fi
cd ..

echo ""
echo "=== Test Case 2: Network Access (Allowed) ==="
echo "Testing access to whitelisted domain..."

cd test_project
if ../run-agent.sh curl -I --connect-timeout 10 https://pypi.org 2>/dev/null; then
	echo "PASS: Agent can access whitelisted domains"
else
	echo "FAIL: Agent cannot access whitelisted domains"
	cd ..
	exit 1
fi
cd ..

echo ""
echo "=== Test Case 3: Network Access (Blocked) ==="
echo "Testing access to non-whitelisted domain..."

cd test_project
if ../run-agent.sh curl -I --connect-timeout 10 https://example.com 2>/dev/null; then
	echo "FAIL: Agent can access non-whitelisted domains"
	cd ..
	exit 1
else
	echo "PASS: Agent cannot access non-whitelisted domains"
fi
cd ..

echo ""
echo "=== Test Case 4: Subfolder Restrictions (File-based) ==="
echo "Testing subfolder restrictions using restricted-paths.txt..."

# Create a copy of the restricted-paths.txt in test_project directory for the test
cp restricted-paths.txt test_project/
cd test_project

# Test that restricted paths show restricted permissions (bind mounts show as d---------  with root owner)
../run-agent.sh ls -la 2>/dev/null | grep '^d---------.*root.*root.*secrets' >/dev/null
SECRETS_RESTRICTED=$?
../run-agent.sh ls -la 2>/dev/null | grep '^d---------.*root.*root.*private' >/dev/null
PRIVATE_RESTRICTED=$?
if [ "$SECRETS_RESTRICTED" -eq 0 ] && [ "$PRIVATE_RESTRICTED" -eq 0 ]; then
	echo "PASS: Restricted directories show no permissions (d--------- root root)"
else
	echo "FAIL: Restricted directories do not show restricted permissions"
	# Show actual output for debugging
	echo "Debug output:"
	../run-agent.sh ls -la 2>/dev/null | grep -E '(secrets|private)'
	cd ..
	exit 1
fi

# Test that public directory is still accessible
if ../run-agent.sh cat public/data.txt 2>/dev/null | grep -q "public data"; then
	echo "PASS: Non-restricted directories are still accessible"
else
	echo "FAIL: Non-restricted directories are not accessible"
	cd ..
	exit 1
fi
cd ..

echo ""
echo "=== Test Case 5: Subfolder Restrictions (Environment Variable) ==="
echo "Testing subfolder restrictions using environment variable..."

cd test_project
# Test with environment variable override (temporarily remove file-based config)
mv restricted-paths.txt restricted-paths.txt.bak
RESTRICTED_PATHS="config.json" ../run-agent.sh ls -la config.json 2>/dev/null | grep '^----------.*root.*root.*config.json' >/dev/null
CONFIG_RESTRICTED=$?
mv restricted-paths.txt.bak restricted-paths.txt
if [ "$CONFIG_RESTRICTED" -eq 0 ]; then
	echo "PASS: Environment variable restrictions work"
else
	echo "FAIL: Environment variable restrictions do not work"
	# Show actual output for debugging
	echo "Debug output:"
	RESTRICTED_PATHS="config.json" ../run-agent.sh ls -la config.json 2>/dev/null
	cd ..
	exit 1
fi
cd ..

# Cleanup
echo ""
echo "Cleaning up test files..."
rm -f outside_secret.txt
rm -rf test_project # Can now delete entire test_project directory without permission issues

# Stop containers and remove network
docker rm -f dns-proxy 2>/dev/null || true
docker network rm agent-net 2>/dev/null || true

echo ""
echo "All tests passed! Sandbox security is working correctly."
