--!optimize 2
--!strict

local Duster = require(script.Duster)
local Janitor17 = require(script.Janitor17)
local Janitor18 = require(script.Janitor18)
local Maid = require(script.Maid)
local Trove = require(script.Trove)
local UltraJanitor18 = require(script.UltraJanitor18)

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

local DIVIDE_BY = 550

local functionsToAdd = 1_000_000 // DIVIDE_BY
local threadsToAdd = 200_000 // DIVIDE_BY
local classesToAdd = 1_000_000 // DIVIDE_BY
local instancesToAdd = 100_000 // DIVIDE_BY

local Add = UltraJanitor18.new().Add
local Cleanup = UltraJanitor18.new().Cleanup

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

	["Janitor 1.18.1"] = function()
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

		janitor:Cleanup()
	end;

	["Ultra Janitor 1.18.1"] = function()
		local janitor = UltraJanitor18.new()

		local functionsJanitor = Add(janitor, UltraJanitor18.new(), "Cleanup")
		for _ = 1, functionsToAdd do
			Add(functionsJanitor, NoOperation, true)
		end
		local threadsJanitor = Add(janitor, UltraJanitor18.new(), "Cleanup")
		for _ = 1, threadsToAdd do
			Add(threadsJanitor, task.delay(5, NoOperation), true)
		end
		local classesJanitor = Add(janitor, UltraJanitor18.new(), "Cleanup")
		for _ = 1, classesToAdd do
			Add(classesJanitor, BasicClass.new(), "Destroy")
		end
		local instancesJanitor = Add(janitor, UltraJanitor18.new(), "Cleanup")
		for _ = 1, instancesToAdd do
			Add(instancesJanitor, Instance.new("Folder"), "Destroy")
		end

		Cleanup(janitor)
	end;

	["Janitor 1.18.0 Unsafe"] = function()
		local janitor = Janitor18.new()
		janitor.UnsafeThreadCleanup = true

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

		janitor:Cleanup()
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

	["Duster"] = function()
		local duster: {Duster.Cleanable} = {}

		local functionsJanitor: {Duster.Cleanable} = {}
		Duster.insert(duster, function()
			Duster.clear(functionsJanitor)
		end)
		for _ = 1, functionsToAdd do
			Duster.insert(functionsJanitor, NoOperation)
		end

		local threadsJanitor: {Duster.Cleanable} = {}
		Duster.insert(duster, function()
			Duster.clear(threadsJanitor)
		end)
		for _ = 1, threadsToAdd do
			Duster.insert(threadsJanitor, task.delay(5, NoOperation))
		end

		local classesJanitor: {Duster.Cleanable} = {}
		Duster.insert(duster, function()
			Duster.clear(classesJanitor)
		end)
		for _ = 1, classesToAdd do
			Duster.insert(classesJanitor, BasicClass.new() :: never)
		end
		local instancesJanitor: {Duster.Cleanable} = {}
		Duster.insert(duster, function()
			Duster.clear(instancesJanitor)
		end)
		for _ = 1, instancesToAdd do
			Duster.insert(instancesJanitor, Instance.new("Folder"))
		end

		Duster.clear(duster)
	end;
})

return Benchmark
