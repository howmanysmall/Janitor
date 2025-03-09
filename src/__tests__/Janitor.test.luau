--!optimize 2
--!strict

_G.__IS_UNIT_TESTING__ = true

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
	AddCleanupFunction: (self: BasicClass, callback: nil | () -> ()) -> BasicClass,
	Destroy: (self: BasicClass) -> (),
}
type Static = {
	ClassName: "BasicClass",
	new: () -> BasicClass,
}
local BasicClass = {} :: BasicClass & Static
BasicClass.ClassName = "BasicClass";
(BasicClass :: any).__index = BasicClass
function BasicClass.new(): BasicClass
	return setmetatable({
		CleanupFunction = nil;
	}, BasicClass) :: never
end
function BasicClass:AddCleanupFunction(callback: nil | () -> ()): BasicClass
	self.CleanupFunction = callback
	return self
end
function BasicClass:Destroy(): ()
	local cleanupFunction = self.CleanupFunction
	if cleanupFunction then
		cleanupFunction()
	end
	table.clear(self)
	setmetatable(self, nil)
end

local function NoOperation(): () end

describe("Janitor.Is", function()
	it("should return true iff the passed value is a Janitor", function()
		local janitor = Janitor.new()
		expect(Janitor.Is(janitor)).toBe(true)
		janitor:Destroy()
	end)

	it("should return false iff the passed value is anything else", function()
		expect(Janitor.Is(NoOperation)).toBe(false)
		expect(Janitor.Is({})).toBe(false)
		expect(Janitor.Is(BasicClass.new())).toBe(false)
	end)
end)

describe("Janitor.new", function()
	it("should create a new Janitor", function()
		local janitor = Janitor.new()
		expect(janitor).toBeDefined()
		expect(Janitor.Is(janitor)).toBe(true)
		janitor:Destroy()
	end)
end)

describe("Janitor.Add", function()
	it("should add things", function()
		local janitor = Janitor.new()
		expect(function()
			janitor:Add(NoOperation, true)
		end).never.toThrow()

		janitor:Destroy()
	end)

	it("should add things with the given index", function()
		local janitor = Janitor.new()
		expect(function()
			janitor:Add(NoOperation, true, "Function")
		end).never.toThrow()

		expect(janitor:Get("Function")).toEqual(expect.any("function"))
		janitor:Destroy()
	end)

	it("should overwrite indexes", function()
		local janitor = Janitor.new()
		local wasRemoved = false
		janitor:Add(function()
			wasRemoved = true
		end, true, "Function")

		janitor:Add(NoOperation, true, "Function")

		expect(wasRemoved).toBe(true)
		janitor:Destroy()
	end)

	it("should return the passed object", function()
		local janitor = Janitor.new()
		local part = janitor:Add(Instance.new("Part"), "Destroy")

		expect(part).toBeDefined()
		expect(part).toEqual(expect.any("Instance"))
		expect(part.ClassName).toBe("Part")
		janitor:Destroy()
	end)

	it("should clean up instances, objects, functions, connections, and threads", function()
		local functionWasDestroyed = false
		local janitorWasDestroyed = false
		local basicClassWasDestroyed = false
		local threadWasRan = false

		local janitor = Janitor.new()
		local part = janitor:Add(Instance.new("Part"), "Destroy")
		part.Parent = ReplicatedStorage

		local connection = janitor:Add(part.ChildRemoved:Connect(NoOperation), "Disconnect")

		janitor:Add(function()
			functionWasDestroyed = true
		end, true)

		janitor:Add(Janitor.new(), "Destroy"):Add(function()
			janitorWasDestroyed = true
		end, true)

		janitor:Add(BasicClass.new(), "Destroy"):AddCleanupFunction(function()
			basicClassWasDestroyed = true
		end)

		janitor:Add(task.delay(1, function()
			threadWasRan = true
		end), true)

		janitor:Destroy()
		expect(part.Parent).toBeUndefined()
		expect(connection.Connected).toBe(false)
		expect(functionWasDestroyed).toBe(true)
		expect(janitorWasDestroyed).toBe(true)
		expect(basicClassWasDestroyed).toBe(true)
		expect(threadWasRan).toBe(false)
	end)

	it("should clean up everything correctly", function()
		local janitor = Janitor.new()
		local cleanedUp = 0
		local totalToAdd = 5000

		for index = 1, totalToAdd do
			janitor:Add(function()
				cleanedUp += 1
			end, true, index)
		end

		for index = totalToAdd, 1, -1 do
			janitor:Remove(index)
		end

		janitor:Destroy()
		expect(cleanedUp).toBe(totalToAdd)
	end)

	it("should infer types if not given", function()
		local janitor = Janitor.new()
		local connection = janitor:Add(ReplicatedStorage.AncestryChanged:Connect(NoOperation))
		janitor:Destroy()

		if IS_DEFERRED then
			task.wait()
		end
		expect(connection.Connected).toBe(false)
	end)
end)

describe("Janitor.AddPromise", function()
	if not Promise then
		return
	end

	it("should add a Promise", function()
		local janitor = Janitor.new()
		local addedPromise = janitor:AddPromise(Promise.delay(60))

		expect(Promise.is(addedPromise)).toBe(true)
		janitor:Destroy()
	end)

	it("should cancel the Promise when destroyed", function()
		local janitor = Janitor.new()
		local wasCancelled = false

		janitor:AddPromise(Promise.new(function(resolve, _, onCancel)
			if onCancel(function()
				wasCancelled = true
			end) then
				return
			end

			return Promise.delay(60):andThen(resolve)
		end))

		janitor:Destroy()
		expect(wasCancelled).toBe(true)
	end)

	it("should not remove any values from the return", function()
		local janitor = Janitor.new()
		local _, value = janitor
			:AddPromise(Promise.new(function(resolve)
				resolve(true)
			end))
			:await()

		expect(value).toBe(true)
		janitor:Destroy()
	end)

	it("should throw if the passed value isn't a Promise", function()
		local janitor = Janitor.new()
		expect(function()
			janitor:AddPromise(BasicClass.new() :: never)
		end).toThrow()

		janitor:Destroy()
	end)
end)

describe("Janitor.Remove", function()
	it("should always return the Janitor", function()
		local janitor = Janitor.new()
		janitor:Add(NoOperation, true, "Function")

		expect(janitor:Remove("Function")).toBe(janitor)
		expect(janitor:Remove("Function")).toBe(janitor)
		janitor:Destroy()
	end)

	it("should always remove the value", function()
		local janitor = Janitor.new()
		local wasRemoved = false

		janitor:Add(function()
			wasRemoved = true
		end, true, "Function")

		janitor:Remove("Function")

		expect(AwaitCondition(function()
			return wasRemoved
		end, 1)).toBe(true)
		janitor:Destroy()
	end)

	it("should properly remove values that are already destroyed", function()
		-- credit to OverHash for pointing out this breaking.
		local janitor = Janitor.new()
		local value = 0

		local subJanitor = Janitor.new()
		subJanitor:Add(function()
			value += 1
		end, true)

		janitor:Add(subJanitor, "Destroy")
		subJanitor:Destroy()
		expect(function()
			janitor:Destroy()
		end).never.toThrow()

		expect(value).toBe(1)
	end)

	it("should clean up everything efficiently", function()
		local janitor = Janitor.new()
		local functionsToAdd = 1_000_000
		local threadsToAdd = 200_000
		local classesToAdd = 1_000_000
		local instancesToAdd = 100_000

		local amountAdded = 0

		for _ = 1, functionsToAdd do
			amountAdded += 1
			janitor:Add(NoOperation, true, amountAdded)
		end
		for _ = 1, threadsToAdd do
			amountAdded += 1
			janitor:Add(task.delay(5, NoOperation), true, amountAdded)
		end
		for _ = 1, classesToAdd do
			amountAdded += 1
			janitor:Add(BasicClass.new(), "Destroy", amountAdded)
		end
		for _ = 1, instancesToAdd do
			amountAdded += 1
			janitor:Add(Instance.new("Part"), "Destroy", amountAdded)
		end

		for index = 1, amountAdded do
			janitor:Remove(index)
		end

		janitor:Destroy()
	end)
end)

describe("Janitor.RemoveList", function()
	it("should always return the Janitor", function()
		local janitor = Janitor.new()
		janitor:Add(NoOperation, true, "Function")

		expect(janitor:RemoveList("Function")).toBe(janitor)
		expect(janitor:RemoveList("Function")).toBe(janitor)
		janitor:Destroy()
	end)

	it("should always remove the value", function()
		local janitor = Janitor.new()
		local wasRemoved = false

		janitor:Add(function()
			wasRemoved = true
		end, true, "Function")

		janitor:RemoveList("Function")

		expect(wasRemoved).toBe(true)
		janitor:Destroy()
	end)

	it("should properly remove multiple values", function()
		local janitor = Janitor.new()
		local oneRan = false
		local twoRan = false
		local threeRan = false

		janitor:Add(function()
			oneRan = true
		end, true, 1)

		janitor:Add(function()
			twoRan = true
		end, true, 2)

		janitor:Add(function()
			threeRan = true
		end, true, 3)

		janitor:RemoveList(1, 2, 3)
		expect(oneRan).toBe(true)
		expect(twoRan).toBe(true)
		expect(threeRan).toBe(true)
	end)
end)

describe("Janitor.Get", function()
	it("should return the value iff it exists", function()
		local janitor = Janitor.new()
		janitor:Add(NoOperation, true, "Function")
		expect(janitor:Get("Function")).toBe(NoOperation)
		janitor:Destroy()
	end)

	it("should return void iff the value doesn't exist", function()
		local janitor = Janitor.new()
		expect(janitor:Get("Function")).toBeUndefined()
		janitor:Destroy()
	end)
end)

describe("Janitor.Cleanup", function()
	it("should cleanup everything", function()
		local janitor = Janitor.new()
		local totalRemoved = 0
		local functionsToAdd = 500

		for _ = 1, functionsToAdd do
			janitor:Add(function()
				totalRemoved += 1
			end, true)
		end

		janitor:Cleanup()
		expect(totalRemoved).toBe(functionsToAdd)

		for _ = 1, functionsToAdd do
			janitor:Add(function()
				totalRemoved += 1
			end, true)
		end

		janitor:Cleanup()
		expect(totalRemoved).toBe(functionsToAdd * 2)
	end)

	it("should be unique", function()
		local janitor = Janitor.new()
		local janitor2 = Janitor.new()
		local totalRemoved = 0
		local functionsToAdd = 500

		expect(janitor.CurrentlyCleaning).toBe(false)
		expect(janitor2.CurrentlyCleaning).toBe(false)

		local hasWaitCompleted = false

		for index = 1, functionsToAdd do
			if index == functionsToAdd then
				janitor:Add(function()
					totalRemoved += 1
					task.wait(1)
					hasWaitCompleted = true
				end, true)
			else
				janitor:Add(function()
					totalRemoved += 1
				end, true)
			end
		end

		task.spawn(function()
			janitor:Cleanup()
		end)

		task.wait()
		expect(janitor.CurrentlyCleaning).toBe(true)
		expect(janitor2.CurrentlyCleaning).toBe(false)

		expect(AwaitCondition(function()
			return hasWaitCompleted
		end, 5)).toBe(true)
		expect(totalRemoved).toBe(functionsToAdd)
	end)
end)

describe("Janitor.Destroy", function()
	it("should cleanup everything", function()
		local janitor = Janitor.new()
		local totalRemoved = 0
		local functionsToAdd = 500

		for _ = 1, functionsToAdd do
			janitor:Add(function()
				totalRemoved += 1
			end, true)
		end

		janitor:Destroy()
		expect(totalRemoved).toBe(functionsToAdd)
	end)

	it("should render the Janitor unusable", function()
		local janitor = Janitor.new()
		janitor:Destroy()
		expect(function()
			janitor:Add(NoOperation, true)
		end).toBeTruthy()
	end)
end)

describe("Janitor.LinkToInstance", function()
	it("should link to an Instance", function()
		local janitor = Janitor.new()
		local part = janitor:Add(Instance.new("Part"), "Destroy")
		part.Parent = ReplicatedStorage

		expect(function()
			janitor:LinkToInstance(part)
		end).never.toThrow()

		janitor:Destroy()
	end)

	it("should cleanup once the Instance is destroyed", function()
		local janitor = Janitor.new()
		local wasCleaned = false

		local part = Instance.new("Part")
		part.Parent = Workspace

		janitor:Add(function()
			wasCleaned = true
		end, true)

		janitor:LinkToInstance(part)

		part:Destroy()
		task.wait(0.1)

		expect(wasCleaned).toBe(true)
		janitor:Destroy()
	end)

	it("should work if the Instance is parented to nil when started", function()
		local janitor = Janitor.new()
		local wasCleaned = false

		local part = Instance.new("Part")
		janitor:Add(function()
			wasCleaned = true
		end, true)

		janitor:LinkToInstance(part)
		part.Parent = Workspace

		part:Destroy()
		expect(AwaitCondition(function()
			return wasCleaned
		end, 1)).toBe(true)
		janitor:Destroy()
	end)

	it("should work if the Instance is parented to nil", function()
		local janitor = Janitor.new()
		local wsCleaned = false

		local part = Instance.new("Part")
		janitor:Add(function()
			wsCleaned = true
		end, true)

		janitor:LinkToInstance(part)

		part:Destroy()
		expect(AwaitCondition(function()
			return wsCleaned
		end, 1)).toBe(true)
		janitor:Destroy()
	end)

	it("shouldn't run if the Instance is removed or parented to nil", function()
		local janitor = Janitor.new()
		local part = Instance.new("Part")
		part.Parent = ReplicatedStorage

		janitor:Add(NoOperation, true, "Function")
		janitor:LinkToInstance(part)

		part.Parent = nil
		expect(janitor:Get("Function")).toBe(NoOperation)
		part.Parent = ReplicatedStorage
		expect(janitor:Get("Function")).toBe(NoOperation)

		part:Destroy()
		task.wait(0.1)
		expect(function()
			janitor:Destroy()
		end).never.toThrow()
	end)
end)

return false
