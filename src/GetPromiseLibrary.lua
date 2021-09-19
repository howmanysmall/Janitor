local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function FindFirstDescendantWithNameAndClassName(Parent: Instance, Name: string, ClassName: string)
	for _, Descendant in ipairs(Parent:GetDescendants()) do
		if Descendant:IsA(ClassName) and Descendant.Name == Name then
			return Descendant
		end
	end

	return nil
end

local function GetPromiseLibrary()
	local Promise = FindFirstDescendantWithNameAndClassName(ReplicatedFirst, "Promise", "ModuleScript")
	if not Promise then
		Promise = FindFirstDescendantWithNameAndClassName(ReplicatedStorage, "Promise", "ModuleScript")
	end

	if Promise then
		return true, require(Promise)
	else
		return false
	end
end

return GetPromiseLibrary
