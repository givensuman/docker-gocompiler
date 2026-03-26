#!/bin/bash

set -euox pipefail

declare -A ARCH_MAP=(
	["amd64"]="x86_64"
	["arm64"]="aarch64"
	["x86"]="i386"
	["386"]="i386"
	["arm"]="arm"
	["riscv64"]="riscv64"
	["ppc64le"]="powerpc64le"
)

declare -A OS_MAP=(
	["linux"]="linux"
	["darwin"]="macos"
	["windows"]="windows"
	["freebsd"]="freebsd"
)

SUPPORTED_PLATFORMS=(
	"linux/amd64"
	"linux/arm64"
	"darwin/amd64"
	"darwin/arm64"
	"windows/amd64"
	"windows/arm64"
	"linux/x86"
	"freebsd/amd64"
	"freebsd/arm64"
)

# ============================================================================
# Helper functions
# ============================================================================

print_usage() {
	cat <<EOF
Usage: $0 [OPTIONS]

Build Go binaries for multiple platforms using Zig as the C compiler.

OPTIONS:
  --include-platforms LIST    Build only specified platforms (comma-separated)
                              e.g., linux/amd64,darwin/arm64,windows/amd64
  --exclude-platforms LIST    Skip building specified platforms (comma-separated)
                              e.g., windows/amd64,windows/arm64
  --list-platforms            Show all supported platforms and exit
  --help                      Show this message

Note: --include-platforms and --exclude-platforms cannot be used together.
      If neither is specified, all supported platforms will be built.

Examples:
  $0                                    # Build all platforms
  $0 --list-platforms                   # List supported platforms
  $0 --include-platforms linux/amd64    # Build only Linux amd64
  $0 --exclude-platforms windows/arm64  # Build all except Windows arm64

EOF
}

list_platforms() {
	echo "Supported platforms:"
	for platform in "${SUPPORTED_PLATFORMS[@]}"; do
		printf "\t$platform\n"
	done
}

validate_platform() {
	local platform="$1"
	for supported in "${SUPPORTED_PLATFORMS[@]}"; do
		if [ "$platform" = "$supported" ]; then
			return 0
		fi
	done
	return 1
}

zig_target() {
	local platform="$1"
	IFS="/" read -r go_os go_arch <<<"$platform"

	if [ -z "${ARCH_MAP[$go_arch]}" ]; then
		echo "Error: Unknown architecture: $go_arch" >&2
		return 1
	fi

	if [ -z "${OS_MAP[$go_os]}" ]; then
		echo "Error: Unknown OS: $go_os" >&2
		return 1
	fi

	local zig_arch="${ARCH_MAP[$go_arch]}"
	local zig_os="${OS_MAP[$go_os]}"

	echo "${zig_arch}-${zig_os}"
}

# Parse command-line arguments
INCLUDE_PLATFORMS=""
EXCLUDE_PLATFORMS=""

while [[ $# -gt 0 ]]; do
	case "$1" in
	--include-platforms)
		if [ -n "$EXCLUDE_PLATFORMS" ]; then
			echo "Error: Cannot use both \
				--include-platforms and --exclude-platforms" >&2
			exit 1
		fi
		INCLUDE_PLATFORMS="$2"
		shift 2
		;;
	--exclude-platforms)
		if [ -n "$INCLUDE_PLATFORMS" ]; then
			echo "Error: Cannot use both \
				--include-platforms and --exclude-platforms" >&2
			exit 1
		fi
		EXCLUDE_PLATFORMS="$2"
		shift 2
		;;
	--list-platforms)
		list_platforms
		exit 0
		;;
	--help)
		print_usage
		exit 0
		;;
	*)
		echo "Unknown option: $1" >&2
		print_usage
		exit 1
		;;
	esac
done

# Determine which platforms to build
PLATFORMS_TO_BUILD=()

if [ -n "$INCLUDE_PLATFORMS" ]; then
	# Parse include list
	IFS="," read -ra include_array <<<"$INCLUDE_PLATFORMS"
	for platform in "${include_array[@]}"; do
		platform=$(echo "$platform" | xargs) # trim whitespace
		if ! validate_platform "$platform"; then
			echo "Error: Unsupported platform: $platform" >&2
			exit 1
		fi
		PLATFORMS_TO_BUILD+=("$platform")
	done
elif [ -n "$EXCLUDE_PLATFORMS" ]; then
	# Parse exclude list
	IFS="," read -ra exclude_array <<<"$EXCLUDE_PLATFORMS"
	declare -A exclude_map
	for platform in "${exclude_array[@]}"; do
		platform=$(echo "$platform" | xargs) # trim whitespace
		if ! validate_platform "$platform"; then
			echo "Error: Unsupported platform: $platform" >&2
			exit 1
		fi
		exclude_map["$platform"]=1
	done

	# Build everything except excluded platforms
	for platform in "${SUPPORTED_PLATFORMS[@]}"; do
		if [ -z "${exclude_map[$platform]}" ]; then
			PLATFORMS_TO_BUILD+=("$platform")
		fi
	done
else
	# Build all supported platforms
	PLATFORMS_TO_BUILD=("${SUPPORTED_PLATFORMS[@]}")
fi

# Pre-flight checks
if [ ! -f "go.mod" ]; then
	echo "Error: No go.mod found. Please mount your project to /app" >&2
	exit 1
fi

if [ ${#PLATFORMS_TO_BUILD[@]} -eq 0 ]; then
	echo "Error: No platforms to build" >&2
	exit 1
fi

mkdir -p dist

# Build for each platform
echo "Building for the following platforms:"
for platform in "${PLATFORMS_TO_BUILD[@]}"; do
	printf "\t$platform\n"
done
echo ""

FAILED_PLATFORMS=()

for PLATFORM in "${PLATFORMS_TO_BUILD[@]}"; do
	# Split the platform string (linux/amd64 -> OS=linux, ARCH=amd64)
	IFS="/" read -r OS ARCH <<<"$PLATFORM"

	# Convert to Zig target format
	ZIG_TARGET=$(zig_target "$PLATFORM")
	if [ $? -ne 0 ]; then
		echo "Skipping $PLATFORM: invalid target"
		FAILED_PLATFORMS+=("$PLATFORM")
		continue
	fi

	OUTPUT="dist/app-${OS}-${ARCH}"
	if [ "$OS" == "windows" ]; then
		OUTPUT="${OUTPUT}.exe"
	fi

	printf "Building for %s (%s) [%s]..." "$OS" "$ARCH" "$ZIG_TARGET"

	# Use Zig as the C compiler for cross-compilation of CGO
	if GOOS="$OS" GOARCH="$ARCH" CGO_ENABLED=1 \
		CC="zig cc -target $ZIG_TARGET" \
		CXX="zig c++ -target $ZIG_TARGET" \
		go build -o "$OUTPUT" . 2>/dev/null; then
		printf "\tdone\n"
	else
		printf "\tFAILED\n"
		FAILED_PLATFORMS+=("$PLATFORM")
	fi
done

if [ ${#FAILED_PLATFORMS[@]} -gt 0 ]; then
	echo ""
	echo "The following platforms failed to build:"
	for platform in "${FAILED_PLATFORMS[@]}"; do
		printf "\t$platform\n"
	done

	exit 1
fi

echo ""
echo "All builds completed successfully."
echo "Check the dist/ directory for output binaries."
exit 0
