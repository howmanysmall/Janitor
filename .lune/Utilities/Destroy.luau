--!native
--!optimize 2
--!strict

local fs = require("@lune/fs")
local process = require("@lune/process")

local HAS_RIM_RAF = (function()
	if process.os ~= "windows" then
		return false
	end

	return pcall(function()
		fs.writeDir("swage")
		process.spawn("rimraf", {"swage"})
	end)
end)()

local Destroy: (path: string) -> ()
if HAS_RIM_RAF then
	function Destroy(path)
		process.spawn("rimraf", {path})
	end
else
	function Destroy(path)
		process.spawn("rm", {"-rf", path})
	end
end

return Destroy
