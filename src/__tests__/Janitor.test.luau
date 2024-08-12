--!optimize 2
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local JestGlobals = require(script.Parent.Parent.Parent.DevPackages.JestGlobals)

local Janitor = require(script.Parent.Parent)
local Promise = require(script.Parent.Parent.Promise)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local IS_DEFERRED = (function()
	local bindableEvent = Instance.new("BindableEvent")
	local handlerRun = false
	bindableEvent.Event:Once(function()
		handlerRun = true
	end)
	bindableEvent:Fire()
	bindableEvent:Destroy()
	return not handlerRun
end)()

local function AwaitCondition(predicate: () -> boolean, timeout: number?): boolean
	local trueTimeout = timeout or 10
	local startTime = os.clock()

	while true do
		if predicate() then
			return true
		end

		if os.clock() - startTime > trueTimeout then
			return false
		end

		task.wait()
	end
end

type BasicClass = {
	CleanupFunction: nil | () -> (),
	AddCleanupFunction: (self: BasicClass, Function: nil | () -> ()) -> BasicClass,
	Destroy: (self: BasicClass) -> (),
}
type Static = {
	ClassName: "BasicClass",
	new: () -> BasicClass,
}
local BasicClass = {} :: BasicClass & Static
BasicClass.ClassName = "BasicClass";
(BasicClass :: any).__index = BasicClass
function BasicClass.new()
	return setmetatable({
		CleanupFunction = nil;
	}, BasicClass) :: never
end
function BasicClass:AddCleanupFunction(Function)
	self.CleanupFunction = Function
	return self
end
function BasicClass:Destroy()
	local CleanupFunction = self.CleanupFunction
	if CleanupFunction then
		CleanupFunction()
	end
	table.clear(self)
	setmetatable(self, nil)
end

local function NoOperation() end

describe("Janitor.Is", function()
	it("should return true iff the passed value is a Janitor", function()
		local NewJanitor = Janitor.new()
		expect(Janitor.Is(NewJanitor)).toBe(true)
		NewJanitor:Destroy()
	end)

	it("should return false iff the passed value is anything else", function()
		expect(Janitor.Is(NoOperation)).toBe(false)
		expect(Janitor.Is({})).toBe(false)
		expect(Janitor.Is(BasicClass.new())).toBe(false)
	end)
end)

describe("Janitor.new", function()
	it("should create a new Janitor", function()
		local NewJanitor = Janitor.new()
		expect(NewJanitor).toBeDefined()
		expect(Janitor.Is(NewJanitor)).toBe(true)
		NewJanitor:Destroy()
	end)
end)

describe("Janitor.Add", function()
	it("should add things", function()
		local NewJanitor = Janitor.new()
		expect(function()
			NewJanitor:Add(NoOperation, true)
		end).never.toThrow()

		NewJanitor:Destroy()
	end)

	it("should add things with the given index", function()
		local NewJanitor = Janitor.new()
		expect(function()
			NewJanitor:Add(NoOperation, true, "Function")
		end).never.toThrow()

		expect(NewJanitor:Get("Function")).toEqual(expect.any("function"))
		NewJanitor:Destroy()
	end)

	it("should overwrite indexes", function()
		local NewJanitor = Janitor.new()
		local WasRemoved = false
		NewJanitor:Add(function()
			WasRemoved = true
		end, true, "Function")

		NewJanitor:Add(NoOperation, true, "Function")

		expect(WasRemoved).toBe(true)
		NewJanitor:Destroy()
	end)

	it("should return the passed object", function()
		local NewJanitor = Janitor.new()
		local Part = NewJanitor:Add(Instance.new("Part"), "Destroy")

		expect(Part).toBeDefined()
		expect(Part).toEqual(expect.any("Instance"))
		expect(Part.ClassName).toBe("Part")
		NewJanitor:Destroy()
	end)

	it("should clean up instances, objects, functions, connections, and threads", function()
		local FunctionWasDestroyed = false
		local JanitorWasDestroyed = false
		local BasicClassWasDestroyed = false
		local ThreadWasRan = false

		local NewJanitor = Janitor.new()
		local Part = NewJanitor:Add(Instance.new("Part"), "Destroy")
		Part.Parent = ReplicatedStorage

		local Connection = NewJanitor:Add(Part.ChildRemoved:Connect(NoOperation), "Disconnect")

		NewJanitor:Add(function()
			FunctionWasDestroyed = true
		end, true)

		NewJanitor:Add(Janitor.new(), "Destroy"):Add(function()
			JanitorWasDestroyed = true
		end, true)

		NewJanitor:Add(BasicClass.new(), "Destroy"):AddCleanupFunction(function()
			BasicClassWasDestroyed = true
		end)

		NewJanitor:Add(task.delay(1, function()
			ThreadWasRan = true
		end), true)

		NewJanitor:Destroy()
		expect(Part.Parent).toBeUndefined()
		expect(Connection.Connected).toBe(false)
		expect(FunctionWasDestroyed).toBe(true)
		expect(JanitorWasDestroyed).toBe(true)
		expect(BasicClassWasDestroyed).toBe(true)
		expect(ThreadWasRan).toBe(false)
	end)

	it("should clean up everything correctly", function()
		local NewJanitor = Janitor.new()
		local CleanedUp = 0
		local TotalToAdd = 5000

		for Index = 1, TotalToAdd do
			NewJanitor:Add(function()
				CleanedUp += 1
			end, true, Index)
		end

		for Index = TotalToAdd, 1, -1 do
			NewJanitor:Remove(Index)
		end

		NewJanitor:Destroy()
		expect(CleanedUp).toBe(TotalToAdd)
	end)

	it("should infer types if not given", function()
		local NewJanitor = Janitor.new()
		local Connection = NewJanitor:Add(ReplicatedStorage.AncestryChanged:Connect(NoOperation))
		NewJanitor:Destroy()

		if IS_DEFERRED then
			task.wait()
		end
		expect(Connection.Connected).toBe(false)
	end)
end)

describe("Janitor.AddPromise", function()
	if not Promise then
		return
	end

	it("should add a Promise", function()
		local NewJanitor = Janitor.new()
		local AddedPromise = NewJanitor:AddPromise(Promise.delay(60))

		expect(Promise.is(AddedPromise)).toBe(true)
		NewJanitor:Destroy()
	end)

	it("should cancel the Promise when destroyed", function()
		local NewJanitor = Janitor.new()
		local WasCancelled = false

		NewJanitor:AddPromise(Promise.new(function(Resolve, _, OnCancel)
			if OnCancel(function()
				WasCancelled = true
			end) then
				return
			end

			return Promise.delay(60):andThen(Resolve)
		end))

		NewJanitor:Destroy()
		expect(WasCancelled).toBe(true)
	end)

	it("should not remove any values from the return", function()
		local NewJanitor = Janitor.new()
		local _, Value = NewJanitor:AddPromise(Promise.new(function(Resolve)
			Resolve(true)
		end)):await()

		expect(Value).toBe(true)
		NewJanitor:Destroy()
	end)

	it("should throw if the passed value isn't a Promise", function()
		local NewJanitor = Janitor.new()
		expect(function()
			NewJanitor:AddPromise(BasicClass.new() :: never)
		end).toThrow()

		NewJanitor:Destroy()
	end)
end)

describe("Janitor.Remove", function()
	it("should always return the Janitor", function()
		local NewJanitor = Janitor.new()
		NewJanitor:Add(NoOperation, true, "Function")

		expect(NewJanitor:Remove("Function")).toBe(NewJanitor)
		expect(NewJanitor:Remove("Function")).toBe(NewJanitor)
		NewJanitor:Destroy()
	end)

	it("should always remove the value", function()
		local NewJanitor = Janitor.new()
		local WasRemoved = false

		NewJanitor:Add(function()
			WasRemoved = true
		end, true, "Function")

		NewJanitor:Remove("Function")

		expect(AwaitCondition(function()
			return WasRemoved
		end, 1)).toBe(true)
		NewJanitor:Destroy()
	end)

	it("should properly remove values that are already destroyed", function()
		-- credit to OverHash for pointing out this breaking.
		local NewJanitor = Janitor.new()
		local X = 0

		local SubJanitor = Janitor.new()
		SubJanitor:Add(function()
			X += 1
		end, true)

		NewJanitor:Add(SubJanitor, "Destroy")
		SubJanitor:Destroy()
		expect(function()
			NewJanitor:Destroy()
		end).never.toThrow()

		expect(X).toBe(1)
	end)
end)

describe("Janitor.RemoveList", function()
	it("should always return the Janitor", function()
		local NewJanitor = Janitor.new()
		NewJanitor:Add(NoOperation, true, "Function")

		expect(NewJanitor:RemoveList("Function")).toBe(NewJanitor)
		expect(NewJanitor:RemoveList("Function")).toBe(NewJanitor)
		NewJanitor:Destroy()
	end)

	it("should always remove the value", function()
		local NewJanitor = Janitor.new()
		local WasRemoved = false

		NewJanitor:Add(function()
			WasRemoved = true
		end, true, "Function")

		NewJanitor:RemoveList("Function")

		expect(WasRemoved).toBe(true)
		NewJanitor:Destroy()
	end)

	it("should properly remove multiple values", function()
		local NewJanitor = Janitor.new()
		local OneRan = false
		local TwoRan = false
		local ThreeRan = false

		NewJanitor:Add(function()
			OneRan = true
		end, true, 1)

		NewJanitor:Add(function()
			TwoRan = true
		end, true, 2)

		NewJanitor:Add(function()
			ThreeRan = true
		end, true, 3)

		NewJanitor:RemoveList(1, 2, 3)
		expect(OneRan).toBe(true)
		expect(TwoRan).toBe(true)
		expect(ThreeRan).toBe(true)
	end)
end)

describe("Janitor.Get", function()
	it("should return the value iff it exists", function()
		local NewJanitor = Janitor.new()
		NewJanitor:Add(NoOperation, true, "Function")
		expect(NewJanitor:Get("Function")).toBe(NoOperation)
		NewJanitor:Destroy()
	end)

	it("should return void iff the value doesn't exist", function()
		local NewJanitor = Janitor.new()
		expect(NewJanitor:Get("Function")).toBeUndefined()
		NewJanitor:Destroy()
	end)
end)

describe("Janitor.Cleanup", function()
	it("should cleanup everything", function()
		local NewJanitor = Janitor.new()
		local TotalRemoved = 0
		local FunctionsToAdd = 500

		for _ = 1, FunctionsToAdd do
			NewJanitor:Add(function()
				TotalRemoved += 1
			end, true)
		end

		NewJanitor:Cleanup()
		expect(TotalRemoved).toBe(FunctionsToAdd)

		for _ = 1, FunctionsToAdd do
			NewJanitor:Add(function()
				TotalRemoved += 1
			end, true)
		end

		NewJanitor:Cleanup()
		expect(TotalRemoved).toBe(FunctionsToAdd * 2)
	end)

	it("should be unique", function()
		local NewJanitor = Janitor.new()
		local Janitor2 = Janitor.new()
		local TotalRemoved = 0
		local FunctionsToAdd = 500

		expect(NewJanitor.CurrentlyCleaning).toBe(false)
		expect(Janitor2.CurrentlyCleaning).toBe(false)

		local HasWaitCompleted = false

		for Index = 1, FunctionsToAdd do
			if Index == FunctionsToAdd then
				NewJanitor:Add(function()
					TotalRemoved += 1
					task.wait(1)
					HasWaitCompleted = true
				end, true)
			else
				NewJanitor:Add(function()
					TotalRemoved += 1
				end, true)
			end
		end

		task.spawn(function()
			NewJanitor:Cleanup()
		end)

		task.wait()
		expect(NewJanitor.CurrentlyCleaning).toBe(true)
		expect(Janitor2.CurrentlyCleaning).toBe(false)

		expect(AwaitCondition(function()
			return HasWaitCompleted
		end, 5)).toBe(true)
		expect(TotalRemoved).toBe(FunctionsToAdd)
	end)
end)

describe("Janitor.Destroy", function()
	it("should cleanup everything", function()
		local NewJanitor = Janitor.new()
		local TotalRemoved = 0
		local FunctionsToAdd = 500

		for _ = 1, FunctionsToAdd do
			NewJanitor:Add(function()
				TotalRemoved += 1
			end, true)
		end

		NewJanitor:Destroy()
		expect(TotalRemoved).toBe(FunctionsToAdd)
	end)

	it("should render the Janitor unusable", function()
		local NewJanitor = Janitor.new()
		NewJanitor:Destroy()
		expect(function()
			NewJanitor:Add(NoOperation, true)
		end).toBeTruthy()
	end)
end)

describe("Janitor.LinkToInstance", function()
	it("should link to an Instance", function()
		local NewJanitor = Janitor.new()
		local Part = NewJanitor:Add(Instance.new("Part"), "Destroy")
		Part.Parent = ReplicatedStorage

		expect(function()
			NewJanitor:LinkToInstance(Part)
		end).never.toThrow()

		NewJanitor:Destroy()
	end)

	it("should cleanup once the Instance is destroyed", function()
		local NewJanitor = Janitor.new()
		local WasCleaned = false

		local Part = Instance.new("Part")
		Part.Parent = Workspace

		NewJanitor:Add(function()
			WasCleaned = true
		end, true)

		NewJanitor:LinkToInstance(Part)

		Part:Destroy()
		task.wait(0.1)

		expect(WasCleaned).toBe(true)
		NewJanitor:Destroy()
	end)

	it("should work if the Instance is parented to nil when started", function()
		local NewJanitor = Janitor.new()
		local WasCleaned = false

		local Part = Instance.new("Part")
		NewJanitor:Add(function()
			WasCleaned = true
		end, true)

		NewJanitor:LinkToInstance(Part)
		Part.Parent = Workspace

		Part:Destroy()
		expect(AwaitCondition(function()
			return WasCleaned
		end, 1)).toBe(true)
		NewJanitor:Destroy()
	end)

	it("should work if the Instance is parented to nil", function()
		local NewJanitor = Janitor.new()
		local WasCleaned = false

		local Part = Instance.new("Part")
		NewJanitor:Add(function()
			WasCleaned = true
		end, true)

		NewJanitor:LinkToInstance(Part)

		Part:Destroy()
		expect(AwaitCondition(function()
			return WasCleaned
		end, 1)).toBe(true)
		NewJanitor:Destroy()
	end)

	it("shouldn't run if the Instance is removed or parented to nil", function()
		local NewJanitor = Janitor.new()
		local Part = Instance.new("Part")
		Part.Parent = ReplicatedStorage

		NewJanitor:Add(NoOperation, true, "Function")
		NewJanitor:LinkToInstance(Part)

		Part.Parent = nil
		expect(NewJanitor:Get("Function")).toBe(NoOperation)
		Part.Parent = ReplicatedStorage
		expect(NewJanitor:Get("Function")).toBe(NoOperation)

		Part:Destroy()
		task.wait(0.1)
		expect(function()
			NewJanitor:Destroy()
		end).never.toThrow()
	end)
end)

return false
