--!native
--!optimize 2
--!strict

local Destroy = require("../Utilities/Destroy")
local PathUtilities = require("../Utilities/PathUtilities")

local fs = require("@lune/fs")
local process = require("@lune/process")

export type FileInstance = {
	FilePath: string,
	IsDirectory: boolean,
	Name: string,
	Parent: FileInstance?,

	GetChildren: (self: FileInstance) -> {FileInstance},
	GetDescendants: (self: FileInstance) -> {FileInstance},
	GetFullName: (self: FileInstance) -> string,

	FindFirstFile: (self: FileInstance, name: string, recursive: boolean?) -> FileInstance?,
	FindFirstDirectory: (self: FileInstance, name: string, recursive: boolean?) -> FileInstance?,

	Read: (self: FileInstance) -> string?,
	Write: (self: FileInstance, source: string) -> (),
	Destroy: (self: FileInstance) -> (),
}
type Private = {
	FilePath: string,
	IsDirectory: boolean,
	Name: string,
	Parent: FileInstance?,

	Children: {FileInstance}?,
	Descendants: {FileInstance}?,

	GetChildren: (self: Private) -> {FileInstance},
	GetDescendants: (self: Private) -> {FileInstance},
	GetFullName: (self: Private) -> string,

	FindFirstFile: (self: Private, name: string, recursive: boolean?) -> FileInstance?,
	FindFirstDirectory: (self: Private, name: string, recursive: boolean?) -> FileInstance?,

	Read: (self: Private) -> string?,
	Write: (self: Private, source: string) -> (),
	Destroy: (self: Private) -> (),
}
type Static = {
	ClassName: "FileInstance",
	Mark: (filePath: string, fileName: string?, parent: FileInstance?) -> FileInstance,
	Is: (value: any) -> boolean,
}
type PrivateStatic = Static & {
	__eq: (self: FileInstance, other: FileInstance) -> boolean,
	__tostring: (self: FileInstance) -> string,
}

local FileInstance = {} :: FileInstance & Static
local Private = FileInstance :: Private & PrivateStatic
FileInstance.ClassName = "FileInstance";
(FileInstance :: any).__index = FileInstance

function FileInstance.Mark(filePath, fileName, parent): FileInstance
	local newFilePath = if fileName then `{filePath}/{fileName}` else filePath

	local self: Private = setmetatable({}, FileInstance) :: never
	self.Children = nil
	self.Descendants = nil

	self.Name = PathUtilities.FileName(newFilePath)
	self.FilePath = newFilePath
	self.IsDirectory = fs.isDir(newFilePath)
	self.Parent = parent

	if not self.IsDirectory then
		-- if it's an init.luau file, the parent is actually the next parent up
		if self.Name == "init.luau" and parent then
			self.Parent = parent.Parent
		end
	end

	return self
end

function FileInstance.Is(value)
	return type(value) == "table" and getmetatable(value) == FileInstance
end

function FileInstance:GetFullName()
	local filePath = self.FilePath
	if string.sub(filePath, 1, 2) == "./" then
		filePath = string.sub(filePath, 3)
	end

	return process.cwd .. filePath
end

function Private:GetChildren()
	-- local cached = self.Children
	-- if cached then
	-- 	return cached
	-- end

	if self.IsDirectory then
		local inDirectory = fs.readDir(self.FilePath)
		local children = table.create(#inDirectory)
		for index, child in inDirectory do
			children[index] = FileInstance.Mark(self.FilePath, child, self)
		end

		self.Children = children
		return children
	end

	local children = {}
	self.Children = children
	return children
end
function Private:GetDescendants()
	-- local cached = self.Descendants
	-- if cached then
	-- 	return cached
	-- end

	local descendants = self:GetChildren()
	local totalDescendants = #descendants
	local length = 0

	if totalDescendants > 0 then
		repeat
			length += 1
			local grandChildren = descendants[length]:GetChildren()
			for index, grandChild in grandChildren do
				descendants[totalDescendants + index] = grandChild
			end
			totalDescendants += #grandChildren
		until length == totalDescendants
	end

	self.Descendants = descendants
	return descendants
end

function FileInstance:FindFirstFile(name, recursive)
	if recursive then
		for _, descendant in self:GetDescendants() do
			if descendant.Name == name then
				return descendant
			end
		end

		return nil
	end

	for _, child in self:GetChildren() do
		if child.Name == name then
			return child
		end
	end

	return nil
end
function FileInstance:FindFirstDirectory(name, recursive)
	if recursive then
		for _, descendant in self:GetDescendants() do
			if descendant.IsDirectory and descendant.Name == name then
				return descendant
			end
		end

		return nil
	end

	for _, child in self:GetChildren() do
		if child.IsDirectory and child.Name == name then
			return child
		end
	end

	return nil
end

function FileInstance:Read()
	return if self.IsDirectory then nil else fs.readFile(self.FilePath)
end
function FileInstance:Write(source)
	if not self.IsDirectory then
		fs.writeFile(self.FilePath, source)
	end
end

function FileInstance:Destroy()
	Destroy(self.FilePath)
	table.clear(self)
	setmetatable(self, nil)
end

function Private:__eq(other)
	return self.FilePath == other.FilePath
end
Private.__tostring = FileInstance.GetFullName
return table.freeze(FileInstance :: Static)
