if (-Not (Test-Path "test-place.rbxl" -PathType Leaf)) {
	rojo build --output test-place.rbxl test-place.project.json
}

try {
	run-in-roblox --place test-place.rbxl --script luau/run-package-tests.luau
}
catch {
	Write-Output "An error occurred: $_"
}
finally {
	if (Test-Path "test-place.rbxl" -PathType Leaf) {
		Remove-Item -Path "test-place.rbxl" -Force -Recurse
	}
}
