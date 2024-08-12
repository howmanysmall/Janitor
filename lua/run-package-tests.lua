local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Jest = require(ReplicatedStorage.DevPackages.Jest)

local processServiceExists, ProcessService = pcall(function()
	local s = "ProcessService"
	return game:GetService(s)
end)

local status, result = Jest.runCLI(ReplicatedStorage.Janitor, {
	all = true;
	ci = false;
	verbose = true;
}, {ReplicatedStorage.Janitor}):awaitStatus()

if status == "Rejected" then
	print(result)
end

if status == "Resolved" and result.results.numFailedTestSuites == 0 and result.results.numFailedTests == 0 then
	if processServiceExists then
		ProcessService:ExitAsync(0)
	end
end

if processServiceExists then
	ProcessService:ExitAsync(1)
end

return nil
