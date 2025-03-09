#!/bin/bash

set -e

cleanup() {
	if [ -f "test-place.rbxl" ]; then
		rm -rf "test-place.rbxl"
	fi
}
trap 'echo "An error occurred"; cleanup' ERR

rojo build --output test-place.rbxl test-place.project.json
run-in-roblox --place test-place.rbxl --script lua/run-package-tests.lua
cleanup
