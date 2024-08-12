--!native
--!optimize 2
--!strict

local fs = require("@lune/fs")

local FileSystemUtilities = {}

function FileSystemUtilities.JustFileName(path: string)
	return string.match(string.match(path, "^(.+)%..+$") or path, "([^\\/]+)$") or path
end
function FileSystemUtilities.JustFileNameWithExtension(path: string)
	return string.match(path, "([^\\/]+)$") or path
end

function FileSystemUtilities.WithoutExtension(path: string): string
	return string.match(path, "^(.+)%..+$") or path
end

function FileSystemUtilities.GetExtension(path: string)
	return string.match(path, "%.([^%.]+)$")
end

type CreatorFunction = (path: string, contents: string?) -> ()
type SafeCreate =
	((name: string, createType: "File", contents: string) -> ())
	& ((name: string, createType: "Directory") -> ())

local function SafeCreate(name: string, createType: "File" | "Directory", contents: string?)
	local CheckerFunction: typeof(fs.isDir) = if createType == "File" then fs.isFile else fs.isDir
	local CreatorFunction = (if createType == "File" then fs.writeFile else fs.writeDir) :: CreatorFunction

	if not CheckerFunction(name) then
		CreatorFunction(name, contents)
	else
		local index = 1
		while CheckerFunction(`{FileSystemUtilities.WithoutExtension(name)} ({index})`) do
			index += 1
		end

		local extension = FileSystemUtilities.GetExtension(name)
		local newFilePath = if extension
			then `{FileSystemUtilities.WithoutExtension(name)} ({index}).{extension}`
			else `{FileSystemUtilities.WithoutExtension(name)} ({index})`

		CreatorFunction(newFilePath, contents)
	end
end
FileSystemUtilities.SafeCreate = SafeCreate :: SafeCreate

function FileSystemUtilities.GetOrCreateDirectory(name: string)
	if not fs.isDir(name) then
		FileSystemUtilities.SafeCreate(name, "Directory")
	end
end

return table.freeze(FileSystemUtilities)
