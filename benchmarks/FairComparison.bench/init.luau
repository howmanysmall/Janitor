--!optimize 2
--!strict

local Janitor17 = require(script.Janitor17)
local Janitor18 = require(script.Janitor18)
local Maid = require(script.Maid)
local Trove = require(script.Trove)

type IProfiler = {
	Begin: (label: string) -> (),
	End: () -> (),

	Start: (label: string) -> (),
	Stop: () -> (),

	Open: (label: string) -> (),
	Close: () -> (),

	Enter: (label: string) -> (),
	Exit: () -> (),

	begin: (label: string) -> (),
	["end"]: () -> (), -- what

	start: (label: string) -> (),
	stop: () -> (),

	open: (label: string) -> (),
	close: () -> (),

	enter: (label: string) -> (),
	exit: () -> (),
}

type IBenchmark<T... = ...nil> = {
	ParameterGenerator: () -> T...?,
	Functions: {[string]: (Profiler: IProfiler, T...) -> ()},
}

local function CreateBenchmark<T...>(
	ParameterGenerator: () -> T...?,
	Functions: {[string]: (Profiler: IProfiler, T...) -> ()}
): IBenchmark<T...>
	return {
		ParameterGenerator = ParameterGenerator;
		Functions = Functions;
	}
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

local functionsToAdd = 1_000_000 // 500
local threadsToAdd = 200_000 // 500
local classesToAdd = 1_000_000 // 500
local instancesToAdd = 100_000 // 500

local Benchmark = CreateBenchmark(function()
	return
end, {
	["Janitor 1.17.0"] = function()
		local janitor = Janitor17.new()

		local functionsJanitor = janitor:Add(Janitor17.new(), "Cleanup")
		for _ = 1, functionsToAdd do
			functionsJanitor:Add(NoOperation, true)
		end
		local threadsJanitor = janitor:Add(Janitor17.new(), "Cleanup")
		for _ = 1, threadsToAdd do
			threadsJanitor:Add(task.delay(5, NoOperation), true)
		end
		local classesJanitor = janitor:Add(Janitor17.new(), "Cleanup")
		for _ = 1, classesToAdd do
			classesJanitor:Add(BasicClass.new(), "Destroy")
		end
		local instancesJanitor = janitor:Add(Janitor17.new(), "Cleanup")
		for _ = 1, instancesToAdd do
			instancesJanitor:Add(Instance.new("Folder"), "Destroy")
		end

		janitor:Destroy()
	end;

	["Janitor 1.18.0"] = function()
		local janitor = Janitor18.new()

		local functionsJanitor = janitor:Add(Janitor18.new(), "Cleanup")
		for _ = 1, functionsToAdd do
			functionsJanitor:Add(NoOperation, true)
		end
		local threadsJanitor = janitor:Add(Janitor18.new(), "Cleanup")
		for _ = 1, threadsToAdd do
			threadsJanitor:Add(task.delay(5, NoOperation), true)
		end
		local classesJanitor = janitor:Add(Janitor18.new(), "Cleanup")
		for _ = 1, classesToAdd do
			classesJanitor:Add(BasicClass.new(), "Destroy")
		end
		local instancesJanitor = janitor:Add(Janitor18.new(), "Cleanup")
		for _ = 1, instancesToAdd do
			instancesJanitor:Add(Instance.new("Folder"), "Destroy")
		end

		janitor:Destroy()
	end;

	["Janitor 1.18.0 Unsafe"] = function()
		local janitor = Janitor18.new()
		janitor.UnsafeThreadCleanup = true

		local functionsJanitor = janitor:Add(Janitor18.new(), "Cleanup", "Functions")
		for index = 1, functionsToAdd do
			functionsJanitor:Add(NoOperation, true, index)
		end
		local threadsJanitor = janitor:Add(Janitor18.new(), "Cleanup", "Threads")
		for index = 1, threadsToAdd do
			threadsJanitor:Add(task.delay(5, NoOperation), true, index)
		end
		local classesJanitor = janitor:Add(Janitor18.new(), "Cleanup", "Classes")
		for index = 1, classesToAdd do
			classesJanitor:Add(BasicClass.new(), "Destroy", index)
		end
		local instancesJanitor = janitor:Add(Janitor18.new(), "Cleanup", "Instances")
		for index = 1, instancesToAdd do
			instancesJanitor:Add(Instance.new("Folder"), "Destroy", index)
		end

		janitor:Destroy()
	end;

	-- Lesser beings
	["Trove 1.5.0"] = function()
		local trove = Trove.new()

		local functionsJanitor = trove:Add(Trove.new(), "Clean")
		for _ = 1, functionsToAdd do
			functionsJanitor:Add(NoOperation)
		end
		local threadsJanitor = trove:Add(Trove.new(), "Clean")
		for _ = 1, threadsToAdd do
			threadsJanitor:Add(task.delay(5, NoOperation))
		end
		local classesJanitor = trove:Add(Trove.new(), "Clean")
		for _ = 1, classesToAdd do
			classesJanitor:Add(BasicClass.new(), "Destroy")
		end
		local instancesJanitor = trove:Add(Trove.new(), "Clean")
		for _ = 1, instancesToAdd do
			instancesJanitor:Add(Instance.new("Folder"), "Destroy")
		end

		trove:Destroy()
	end;

	["Maid"] = function()
		local maid = Maid.new()

		local functionsJanitor = maid:Add(Maid.new())
		for _ = 1, functionsToAdd do
			functionsJanitor:Add(NoOperation)
		end
		local threadsJanitor = maid:Add(Maid.new())
		for _ = 1, threadsToAdd do
			threadsJanitor:Add(task.delay(5, NoOperation))
		end
		local classesJanitor = maid:Add(Maid.new())
		for _ = 1, classesToAdd do
			classesJanitor:Add(BasicClass.new())
		end
		local instancesJanitor = maid:Add(Maid.new())
		for _ = 1, instancesToAdd do
			instancesJanitor:Add(Instance.new("Folder"))
		end

		maid:Destroy()
	end;
})

return Benchmark
