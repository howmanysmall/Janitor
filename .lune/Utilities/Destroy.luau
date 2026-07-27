--!native
--!strict

local fs = require("@lune/fs")

local function Destroy(path: string): ()
	if fs.isDir(path) then
		fs.removeDir(path)
		return
	end

	if fs.isFile(path) then
		fs.removeFile(path)
	end
end

return Destroy
