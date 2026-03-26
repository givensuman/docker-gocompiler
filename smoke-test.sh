#!/bin/bash
set -e

echo "========================================="
echo "Docker-GoCompiler Smoke Test"
echo "========================================="
echo ""

# Create test directory
TEST_DIR="$(pwd)/test-project"
echo "Creating test Go project in: $TEST_DIR"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Initialize Go module
echo "Initializing Go module..."
go mod init test

# Create main.go with CGO
echo "Creating main.go with CGO..."
cat >main.go <<'EOF'
package main

import "C"
import "fmt"

func main() {
    fmt.Println("yipee!")
}
EOF

echo ""
echo "Test project created:"
ls -la

# Build Docker image locally
echo ""
echo "========================================="
echo "Building Docker image..."
echo "========================================="
cd /var/home/given/Dev/docker-gocompiler
docker build -t docker-gocompiler:test .

# Run smoke test
echo ""
echo "========================================="
echo "Running cross-compilation..."
echo "========================================="
cd "$TEST_DIR"
docker run --rm -v "$(pwd):/app" docker-gocompiler:test

# Check if dist directory exists and is not empty
echo ""
echo "========================================="
echo "Verifying output..."
echo "========================================="

if [ ! -d "dist" ]; then
	echo "❌ FAILED: dist/ directory does not exist"
	exit 1
fi

if [ ! "$(ls -A dist)" ]; then
	echo "❌ FAILED: dist/ directory is empty"
	ls -la dist/
	exit 1
fi

echo "✅ dist/ directory exists and contains files:"
ls -lah dist/

# Try to run the linux-amd64 binary
echo ""
echo "Testing linux-amd64 binary..."
if [ -f "dist/app-linux-amd64" ]; then
	chmod +x dist/app-linux-amd64
	output=$(./dist/app-linux-amd64)
	if echo "$output" | grep -q "yipee!"; then
		echo "✅ Binary execution successful: $output"
	else
		echo "❌ Binary execution did not produce expected output"
		echo "Got: $output"
		exit 1
	fi
else
	echo "❌ app-linux-amd64 binary not found"
	exit 1
fi

echo ""
echo "========================================="
echo "✅ ALL TESTS PASSED!"
echo "========================================="
echo ""
echo "Test artifacts are in: $TEST_DIR"
echo "To clean up: rm -rf $TEST_DIR"
