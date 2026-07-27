#!/usr/bin/env sh

# Runs a command silently; only shows output on failure

output=$("$@" 2>&1)
code=$?
[ $code -ne 0 ] && printf '%s\n' "$output"
exit $code
