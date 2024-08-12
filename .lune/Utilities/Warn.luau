--!native
--!optimize 2
--!strict

local Chalk = require("../Packages/Chalk")

local ORANGE = Chalk.Rgb(255, 142, 60)

local function Concat(...: unknown)
	local length = select("#", ...)
	if length == 0 then
		return ""
	end

	if length == 1 then
		return tostring(...)
	end

	if length == 2 then
		local a, b = ...
		return tostring(a) .. " " .. tostring(b)
	end

	if length == 3 then
		local a, b, c = ...
		return tostring(a) .. " " .. tostring(b) .. " " .. tostring(c)
	end

	if length == 4 then
		local a, b, c, d = ...
		return tostring(a) .. " " .. tostring(b) .. " " .. tostring(c) .. " " .. tostring(d)
	end

	if length == 5 then
		local a, b, c, d, e = ...
		return tostring(a) .. " " .. tostring(b) .. " " .. tostring(c) .. " " .. tostring(d) .. " " .. tostring(e)
	end

	if length == 6 then
		local a, b, c, d, e, f = ...
		return tostring(a)
			.. " "
			.. tostring(b)
			.. " "
			.. tostring(c)
			.. " "
			.. tostring(d)
			.. " "
			.. tostring(e)
			.. " "
			.. tostring(f)
	end

	local array = table.create(length)
	for index = 1, length do
		array[index] = tostring(select(index, ...))
	end
	return table.concat(array, " ")
end

local function Warn(...)
	warn(ORANGE(Concat(...)))
end

return Warn
