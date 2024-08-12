--!native
--!optimize 2
--!strict

local Destroy = require("./Utilities/Destroy")
local FileInstance = require("./Classes/FileInstance")
local PathUtilities = require("./Utilities/PathUtilities")
local warn = require("./Utilities/Warn")

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")

local PROJECT_NAME = "built-release.project.json"
local SOURCEMAP_NAME = "built-sourcemap.json"

local EXTRA_STEPS: {
	{
		Enabled: boolean,
		Name: string,
		Function: (builtProject: FileInstance.FileInstance) -> boolean,
	}
} =
	{
		{
			Enabled = true;
			Name = "Fix Promise import";
			Function = function(builtProject)
				local promise = builtProject:FindFirstFile("Promise.luau")
				if not promise then
					return false
				end

				local promiseFileSource = promise:Read()
				if not promiseFileSource then
					return false
				end

				promise:Write(
					(
						string.gsub(
							promiseFileSource,
							"local Packages = script.Parent.Parent",
							"local Packages = script.Parent.Packages"
						)
					)
				)

				return true
			end;
		};
	}

type Cleanup = () -> ()

local function CreateBuildProject(): Cleanup
	if fs.isDir("built-project") then
		Destroy("built-project")
	end

	fs.copy("src", "built-project", true)
	local builtProject = FileInstance.Mark("built-project")
	if not fs.isDir("Packages") then
		Destroy("Packages")
	end

	local installResult = process.spawn("wally", {"install"})
	if not installResult.ok then
		warn(`wally install failed: {installResult.stderr} ({installResult.code})`)
		return function()
			builtProject:Destroy()
		end
	end

	local packages = FileInstance.Mark("Packages")

	local tests = builtProject:FindFirstDirectory("__tests__")
	if tests then
		tests:Destroy()
	end

	local configuration = builtProject:FindFirstFile("jest.config.luau")
	if configuration then
		configuration:Destroy()
	end

	local descendants = builtProject:GetDescendants()
	for _, child in builtProject:GetChildren() do
		if child.IsDirectory and #child:GetChildren() == 0 then
			child:Destroy()
		end
	end

	for _, extraStep in EXTRA_STEPS do
		if not extraStep.Enabled then
			continue
		end
		extraStep.Function(builtProject)
	end

	if not fs.isFile(PROJECT_NAME) then
		local json = serde.encode("json", {
			globIgnorePaths = {
				"**/*.spec.luau";
				"**/*.spec.lua";
				"**/*.story.luau";
				"**/*.story.lua";
				"**/__tests__";
				"**/*.test.luau";
				"**/*.test.lua";
			};
			name = "Janitor";
			tree = {
				["$path"] = "built-project";
				Packages = {["$path"] = "Packages"};
			};
		}, false)
		fs.writeFile(PROJECT_NAME, json)
	end

	local sourcemapResult = process.spawn("rojo", {"sourcemap", "--output", SOURCEMAP_NAME, PROJECT_NAME})
	if not sourcemapResult.ok then
		warn(`rojo sourcemap failed: {sourcemapResult.stderr} ({sourcemapResult.code})`)
		return function()
			Destroy(PROJECT_NAME)
			builtProject:Destroy()
		end
	end

	local packageTypesResult = process.spawn("wally-package-types", {"--sourcemap", SOURCEMAP_NAME, "Packages/"})
	if not packageTypesResult.ok then
		warn(`wally-package-types failed: {packageTypesResult.stderr} ({packageTypesResult.code})`)
		return function()
			Destroy(PROJECT_NAME)
			Destroy(SOURCEMAP_NAME)
			builtProject:Destroy()
		end
	end

	local packageNames: {[string]: string} = {}
	for _, child in packages:GetChildren() do
		if child.IsDirectory then
			continue
		end

		local packageName = PathUtilities.FileNameNoExtension(child.Name)
		if not packageName or packageNames[packageName] then
			continue
		end

		packageNames[packageName] = `local {packageName} = require%(script.(.*).{packageName}%)`
		print("Adding", packageName)
	end

	for _, descendant in descendants do
		if descendant.IsDirectory or descendant.Name == "README.luau" then
			continue
		end

		local extension = PathUtilities.ExtensionName(descendant.Name)
		if not extension then
			warn("No extension found for", descendant:GetFullName())
			continue
		end

		if extension ~= ".lua" and extension ~= ".luau" then
			continue
		end

		local fileSource = descendant:Read()
		if not fileSource then
			warn("Failed to read", descendant:GetFullName())
			continue
		end

		local splitByNewline = string.split(fileSource, "\n")
		local wasModified = false
		for index, line in splitByNewline do
			for packageName, pattern in packageNames do
				local parentPath = string.match(line, pattern)
				if not parentPath then
					continue
				end

				local requirePath = {"script"}
				local length = 1

				local wasFound = false

				local object = descendant
				while true do
					local parent = object.Parent

					length += 1
					requirePath[length] = "Parent"

					if parent == builtProject then
						requirePath[length + 1] = "Packages"
						requirePath[length + 2] = packageName
						wasFound = true
						break
					end

					if not parent then
						warn("Failed to find parent for", object:GetFullName())
						break
					end

					object = parent
				end

				if wasFound then
					local newLine = `local {packageName} = require({table.concat(requirePath, ".")})`
					splitByNewline[index] = newLine
					wasModified = true
				end
			end
		end

		if wasModified then
			descendant:Write(table.concat(splitByNewline, "\n"))
		end
	end

	return function()
		Destroy(PROJECT_NAME)
		Destroy(SOURCEMAP_NAME)
		builtProject:Destroy()
	end
end

local function Install(lastCleanup: Cleanup?): Cleanup
	local rbxmResult = process.spawn("rojo", {"build", "--output", "Janitor.rbxm", PROJECT_NAME})
	if not rbxmResult.ok then
		warn(`rojo build rbxm failed: {rbxmResult.stderr} ({rbxmResult.code})`)
		return function()
			if lastCleanup then
				lastCleanup()
			end
		end
	end

	local rbxmxResult = process.spawn("rojo", {"build", "--output", "Janitor.rbxmx", PROJECT_NAME})
	if not rbxmxResult.ok then
		warn(`rojo build rbxmx failed: {rbxmxResult.stderr} ({rbxmxResult.code})`)
		return function()
			if lastCleanup then
				lastCleanup()
			end
		end
	end

	return function()
		if lastCleanup then
			lastCleanup()
		end
	end
end

local cleanup = Install(CreateBuildProject())
stdio.prompt("confirm", "Press enter to continue and cleanup", true)

cleanup()

local sourcemapResult = process.spawn("rojo", {"sourcemap", "--output", "sourcemap.json", "place.project.json"})
if not sourcemapResult.ok then
	warn(`rojo sourcemap failed: {sourcemapResult.stderr} ({sourcemapResult.code})`)
	process.exit(1)
end

local packageTypesResult = process.spawn("wally-package-types", {"--sourcemap", "sourcemap.json", "Packages/"})
if not packageTypesResult.ok then
	warn(`wally-package-types failed: {packageTypesResult.stderr} ({packageTypesResult.code})`)
	process.exit(1)
end

local devPackageTypesResult = process.spawn("wally-package-types", {"--sourcemap", "sourcemap.json", "DevPackages/"})
if not devPackageTypesResult.ok then
	warn(`wally-package-types failed: {devPackageTypesResult.stderr} ({devPackageTypesResult.code})`)
	process.exit(1)
end
