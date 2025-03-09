#!/bin/bash

contents="{ \"FFlagEnableLoadModule\": true }"

path="/Applications/RobloxStudio.app/Contents/MacOS/ClientSettings/ClientAppSettings.json"

mkdir -p $(dirname $path)
touch $path
echo $contents >$path
