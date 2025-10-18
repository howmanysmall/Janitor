#!/bin/bash

set -euo pipefail

PROJECT_FILE="test-place.project.json"
OUTPUT_FILE="test-place.rbxl"
TEST_SCRIPT="luau/run-package-tests.luau"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

function print-status() {
	echo -e "${GREEN}[INFO]${NC} $1"
}

function print-warning() {
	echo -e "${YELLOW}[WARN]${NC} $1"
}

function print-error() {
	echo -e "${RED}[ERROR]${NC} $1"
}

function cleanup() {
	if [ -f "$OUTPUT_FILE" ]; then
		print-status "Cleaning up $OUTPUT_FILE"
		rm -f "$OUTPUT_FILE"
	fi
}

# Error handler
function error-handler() {
	local exitCode=$?
	print-error "Script failed with exit code $exitCode"
	cleanup
	exit $exitCode
}

# Set up traps
trap error-handler ERR
trap cleanup EXIT

# Check if required tools are available
function check-dependencies() {
	local missingDependencies=()

	if ! command -v rojo &>/dev/null; then
		missingDependencies+=("rojo")
	fi

	if ! command -v run-in-roblox &>/dev/null; then
		missingDependencies+=("run-in-roblox")
	fi

	if [ ${#missingDependencies[@]} -ne 0 ]; then
		print-error "Missing required dependencies: ${missingDependencies[*]}"
		print-error "Please ensure Rokit is installed and tools are available."
		print-error "Run 'rokit install' to install dependencies."
		exit 1
	fi
}

# Check if required files exist
function check-files() {
	if [ ! -f "$PROJECT_FILE" ]; then
		print-error "Project file '$PROJECT_FILE' not found"
		exit 1
	fi

	if [ ! -f "$TEST_SCRIPT" ]; then
		print-error "Test script '$TEST_SCRIPT' not found"
		exit 1
	fi
}

function main() {
	print-status "Starting test run..."

	check-dependencies
	check-files

	# Build the test place (only if it doesn't exist or force rebuild)
	if [ ! -f "$OUTPUT_FILE" ]; then
		print-status "Building test place..."
		rojo build --output "$OUTPUT_FILE" "$PROJECT_FILE"

		# Verify build succeeded
		if [ ! -f "$OUTPUT_FILE" ]; then
			print-error "Build failed - output file '$OUTPUT_FILE' was not created"
			exit 1
		fi
	else
		print-warning "Using existing $OUTPUT_FILE (delete it to force rebuild)"
	fi

	# Run tests
	print-status "Running tests..."
	run-in-roblox --place "$OUTPUT_FILE" --script "$TEST_SCRIPT"

	print-status "Tests completed successfully"
}

# Run main function
main "$@"
