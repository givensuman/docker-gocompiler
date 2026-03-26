#!/bin/bash

PLATFORMS=("linux/amd64" "linux/arm64" "windows/amd64" "darwin/amd64" "darwin/arm64")

if [ ! -f "go.mod" ]; then
	echo "Error: No go.mod found. Please mount your project to /app"
	exit 1
fi

mkdir -p dist

for PLATFORM in "${PLATFORMS[@]}"; do
	# Split the string (linux/amd64 -> OS=linux, ARCH=amd64)
	IFS="/" read -r OS ARCH <<<"$PLATFORM"

	OUTPUT="dist/app-${OS}-${ARCH}"
	if [ "$OS" == "windows" ]; then OUTPUT="${OUTPUT}.exe"; fi

	printf "Building for $OS ($ARCH)..."

	# We use Zig as the C compiler for cross-compilation of CGO
	GOOS=$OS GOARCH=$ARCH CGO_ENABLED=1 \
		CC="zig cc -target ${ARCH}-${OS}" \
		CXX="zig c++ -target ${ARCH}-${OS}" \
		go build -o "$OUTPUT" .

	if [ $? -eq 0 ]; then
		printf "   done\n"
	else
		printf "   FAILED\n"
	fi
done

echo "All builds completed. Check the dist/ directory for the output binaries."
