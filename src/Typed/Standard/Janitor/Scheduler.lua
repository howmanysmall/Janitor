-- Scheduler
-- Original by Validark
-- Rewritten to fit the style of the repo by pobammer

-- Original: https://github.com/Validark/Roblox-TS-Libraries/tree/master/delay-spawn-wait

local RunService = game:GetService("RunService")
local Heartbeat = RunService.Heartbeat
local TimeFunction = RunService:IsRunning() and time or os.clock

local Scheduler = {
	TimeFunction = TimeFunction;
}

local Queue = {}
local CurrentLength = 0
local Connection

local function HeartbeatStep()
	local ClockTick = TimeFunction()

	repeat
		local Current = Queue[1]
		if Current == nil or Current.EndTime > ClockTick then
			break
		end

		local Done = CurrentLength == 1

		if Done then
			Queue[1] = nil
			CurrentLength = 0
			Connection = Connection:Disconnect()
		else
			local LastNode = Queue[CurrentLength]
			Queue[CurrentLength] = nil
			CurrentLength -= 1
			local TargetIndex = 1

			while true do
				local ChildIndex = 2 * TargetIndex
				if ChildIndex > CurrentLength then
					break
				end

				local MinChild = Queue[ChildIndex]
				local RightChildIndex = ChildIndex + 1

				if RightChildIndex <= CurrentLength then
					local RightChild = Queue[RightChildIndex]
					if RightChild.EndTime < MinChild.EndTime then
						ChildIndex = RightChildIndex
						MinChild = RightChild
					end
				end

				if LastNode.EndTime < MinChild.EndTime then
					break
				end

				Queue[TargetIndex] = MinChild
				TargetIndex = ChildIndex
			end

			Queue[TargetIndex] = LastNode
		end

		local Arguments = Current.Arguments
		local Function = Current.Function

		if typeof(Function) == "Instance" then
			if Arguments then
				Function:Fire(table.unpack(Arguments, 2, Arguments[1]))
			else
				Function:Fire(TimeFunction() - Current.StartTime)
			end
		else
			local BindableEvent = Instance.new("BindableEvent")

			if Arguments then
				BindableEvent.Event:Connect(function()
					Function(table.unpack(Arguments, 2, Arguments[1]))
				end)
			else
				BindableEvent.Event:Connect(Function)
			end

			BindableEvent:Fire(TimeFunction() - Current.StartTime)
			BindableEvent:Destroy()
		end
	until Done
end

--[[**
	"Overengineered" `delay` reimplementation. Takes parameters. This should take significantly less time to execute than the original.
	@param [number?] DelayTime The amount of time to delay for.
	@param [function] Function The function to call.
	@param [...?] ... Optional arguments to call the function with.
	@returns [void]
**--]]
function Scheduler.Delay(Seconds, Function, ...)
	-- If seconds is nil, -INF, INF, NaN, or less than MINIMUM_DELAY, assume seconds is MINIMUM_DELAY.
	if Seconds == nil or Seconds <= 0 or Seconds == math.huge then
		Seconds = 0
	end

	local StartTime = TimeFunction()
	local EndTime = StartTime + Seconds
	local Length = select("#", ...)

	if Connection == nil then -- first is nil when connection is nil
		Connection = Heartbeat:Connect(HeartbeatStep)
	end

	local Node = {
		Arguments = Length > 0 and {Length + 1, ...};
		EndTime = EndTime;
		Function = Function;
		StartTime = StartTime;
	}

	local TargetIndex = CurrentLength + 1
	CurrentLength = TargetIndex

	while true do
		local ParentIndex = (TargetIndex - TargetIndex % 2) / 2
		if ParentIndex < 1 then
			break
		end

		local ParentNode = Queue[ParentIndex]
		if ParentNode.EndTime < Node.EndTime then
			break
		end

		Queue[TargetIndex] = ParentNode
		TargetIndex = ParentIndex
	end

	Queue[TargetIndex] = Node
end

local Scheduler_Delay = Scheduler.Delay

--[[**
	Overengineered `wait` reimplementation. Uses `Scheduler.Delay`.
	@param [number?] Seconds The amount of time to yield for.
	@returns [number] The actual time yielded.
**--]]
function Scheduler.Wait(Seconds)
	local BindableEvent = Instance.new("BindableEvent")
	Scheduler_Delay(math.max(Seconds or 0.03, 0.029), BindableEvent)
	return BindableEvent.Event:Wait()
end

--[[**
	Significantly simpler reimplementation of `wait`. This works the exact same, just a bit worse performing.
	@param [number?] Seconds The amount of time to yield for.
	@returns [number] The actual time yielded.
**--]]
function Scheduler.Wait2(Seconds)
	Seconds = math.max(Seconds or 0.03, 0.029)
	local TimeRemaining = Seconds

	while TimeRemaining > 0 do
		TimeRemaining -= Heartbeat:Wait()
	end

	return Seconds - TimeRemaining
end

-- @source https://devforum.roblox.com/t/psa-you-can-get-errors-and-stack-traces-from-coroutines/455510/2
local function Finish(Thread, Success, ...)
	if not Success then
		warn(debug.traceback(Thread, tostring((...))))
	end

	return Success, ...
end

--[[**
	Spawns the passed function immediately using coroutines. This keeps the traceback as well, and warns if the function errors.
	@param [function] Function The function you are calling.
	@param [...?] ... The optional arguments to call the function with.
	@returns [(boolean, ...)] Whether or not the call was successful and the returned values.
**--]]
function Scheduler.Spawn(Function, ...)
	local Thread = coroutine.create(Function)
	return Finish(Thread, coroutine.resume(Thread, ...))
end

--[[**
	Spawns the passed function immediately using a BindableEvent. This keeps the traceback as well, and will throw an error if the function errors.
	@param [function] Function The function you are calling.
	@param [...?] ... The optional arguments to call the function with.
	@returns [void]
**--]]
function Scheduler.FastSpawn(Function, ...)
	local Arguments = table.pack(...)
	local BindableEvent = Instance.new("BindableEvent")
	BindableEvent.Event:Connect(function()
		Function(table.unpack(Arguments, 1, Arguments.n))
	end)

	BindableEvent:Fire()
	BindableEvent:Destroy()
end

--[[**
	Spawns the passed function with a delay using Heartbeat. This keeps the traceback as well, and will throw an error if the function errors.
	@param [function] Function The function you are calling.
	@param [...?] ... The optional arguments to call the function with.
	@returns [void]
**--]]
function Scheduler.SpawnDelayed(Function, ...)
	local Length = select("#", ...)
	if Length > 0 then
		local Arguments = {...}
		local HeartbeatConnection

		HeartbeatConnection = Heartbeat:Connect(function()
			HeartbeatConnection:Disconnect()
			Function(table.unpack(Arguments, 1, Length))
		end)
	else
		local HeartbeatConnection
		HeartbeatConnection = Heartbeat:Connect(function()
			HeartbeatConnection:Disconnect()
			Function()
		end)
	end
end

--[[**
	A recreation of `spawn`, delay and all. This should in theory run better than the original spawn, as well as not using a garbage legacy scheduler. Use it Michal.
	@param [function] Function The function you are calling.
	@param [...?] ... The optional arguments to call the function with.
	@returns [void]
**--]]
function Scheduler.NewSpawn(Function, ...)
	local StartTime = TimeFunction()
	local EndTime = StartTime + 0.03
	local Length = select("#", ...)

	if Connection == nil then -- first is nil when connection is nil
		Connection = Heartbeat:Connect(HeartbeatStep)
	end

	local Node = {
		Arguments = Length > 0 and {Length + 1, ...};
		EndTime = EndTime;
		Function = Function;
		StartTime = StartTime;
	}

	local TargetIndex = CurrentLength + 1
	CurrentLength = TargetIndex

	while true do
		local ParentIndex = (TargetIndex - TargetIndex % 2) / 2
		if ParentIndex < 1 then
			break
		end

		local ParentNode = Queue[ParentIndex]
		if ParentNode.EndTime < Node.EndTime then
			break
		end

		Queue[TargetIndex] = ParentNode
		TargetIndex = ParentIndex
	end

	Queue[TargetIndex] = Node
end

return Scheduler
