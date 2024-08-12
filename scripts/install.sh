#!/bin/bash

# Remove old packages folder
if [ -d "Packages" ]; then
    rm -rf ./Packages
fi
if [ -d "DevPackages" ]; then
    rm -rf ./DevPackages
fi

# Install packages
wally install

if [ ! -d "Packages" ]; then
    mkdir "Packages"
fi
if [ ! -d "DevPackages" ]; then
    mkdir "DevPackages"
fi

# Sourcemap generation
rojo sourcemap --output sourcemap.json test-place.project.json

# Fix the types (why is this not native???)
wally-package-types --sourcemap sourcemap.json Packages/
wally-package-types --sourcemap sourcemap.json DevPackages/
