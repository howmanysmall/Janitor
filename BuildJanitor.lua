local ffi = require("ffi")

-- stylua: ignore
ffi.cdef[[
	int printf(const char * Format, ...);
]]

local function print(...)
	local Array = {}
	for Index = 1, select("#", ...) do
		Array[Index] = tostring(select(Index, ...))
	end

	ffi.C.printf("%s\n", table.concat(Array, " "))
end

local PROJECT_FILES = {"default.project.json", "janitorpromise.project.json"}
local PROJECT_NAMES = {"Janitor", "JanitorPromise"}

for Index, ProjectFile in ipairs(PROJECT_FILES) do
	local ProjectName = PROJECT_NAMES[Index]
	os.execute(string.format("rojo build -o %s.rbxm %s", ProjectName, ProjectFile))
	os.execute(string.format("rojo build -o %s.rbxmx %s", ProjectName, ProjectFile))
	print("Built", ProjectName)
end

return 1
