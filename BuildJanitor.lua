local ffi = require("ffi")

-- stylua: ignore
ffi.cdef[[
	int printf(const char * Format, ...);
]]

os.execute(string.format("rojo build -o Janitor.rbxm default.project.json"))
os.execute(string.format("rojo build -o Janitor.rbxmx default.project.json"))
ffi.C.printf("Built Janitor!\n")
return 1
