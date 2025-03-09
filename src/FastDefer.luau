--!native
--!optimize 2
--!strict

local FreeThreads: {thread} = table.create(500)
local function RunFunction<Arguments...>(callback: (Arguments...) -> (), thread: thread, ...: Arguments...)
	callback(...)
	table.insert(FreeThreads, thread)
end

local function Yield()
	while true do
		RunFunction(coroutine.yield())
	end
end

local function FastDefer<Arguments...>(callback: (Arguments...) -> (), ...: Arguments...): thread
	local thread: thread
	local freeAmount = #FreeThreads

	if freeAmount > 0 then
		thread = FreeThreads[freeAmount]
		FreeThreads[freeAmount] = nil
	else
		thread = coroutine.create(Yield)
		coroutine.resume(thread)
	end

	-- TODO: This might be able to throw?
	return task.defer(thread, callback, thread, ...)
end

return FastDefer
