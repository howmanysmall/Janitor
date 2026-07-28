--!optimize 2
--!strict

-- Compiled with L+ C Edition
-- Janitor
-- Original by Validark
-- Modifications by pobammer
-- roblox-ts support by OverHash and Validark
-- LinkToInstance fixed by Elttob.
-- Cleanup edge cases fixed by codesenseAye.
-- Data-oriented storage rewrite (packed slot arrays + u8 disposal tags).

local FastDefer = require(script.FastDefer)
local Promise = require(script.Promise)
type Promise<T...> = Promise.TypedPromise<T...>

local LinkToInstanceIndex = setmetatable({}, {
	__tostring = function()
		return "LinkToInstanceIndex"
	end;
})

local INVALID_METHOD_NAME =
	"Object is a %* and as such expected `true?` for the method name and instead got %*. Traceback: %*"
local METHOD_NOT_FOUND_ERROR = "Object %* doesn't have method %*, are you sure you want to add it? Traceback: %*"
local NOT_A_PROMISE = "Invalid argument #1 to 'Janitor:AddPromise' (Promise expected, got %* (%*)) Traceback: %*"

type BooleanOrString = boolean | string

-- Disposal tags. The disposal method for a value never changes, so it is
-- resolved exactly once at `Add` time and stored as a u8 in a buffer. The
-- cleanup hot loop then just reads a byte and branches on an integer - no
-- `typeof`, no string comparisons, no method sniffing.
local TAG_CALL = 0
local TAG_THREAD = 1
local TAG_DISCONNECT = 2
local TAG_DESTROY = 3
local TAG_DESTROY_INSTANCE = 4
local TAG_CUSTOM = 5

local INITIAL_TAGS_CAPACITY = 16

export type Janitor = typeof(setmetatable({} :: {
	CurrentlyCleaning: boolean,
	SuppressInstanceReDestroy: boolean,
	UnsafeThreadCleanup: boolean,

	Add: <T>(self: Janitor, object: T, methodName: BooleanOrString?, index: any?) -> T,
	AddObject: <T, A...>(
		self: Janitor,
		constructor: {new: (A...) -> T},
		methodName: BooleanOrString?,
		index: any?,
		A...
	) -> T,
	AddPromise: <T...>(self: Janitor, promiseObject: Promise<T...>, index: unknown?) -> Promise<T...>,

	Remove: (self: Janitor, index: any) -> Janitor,
	RemoveNoClean: (self: Janitor, index: any) -> Janitor,

	RemoveList: (self: Janitor, ...any) -> Janitor,
	RemoveListNoClean: (self: Janitor, ...any) -> Janitor,

	Get: (self: Janitor, index: any) -> any?,
	GetAll: (self: Janitor) -> {[any]: any},

	Cleanup: (self: Janitor) -> (),
	Destroy: (self: Janitor) -> (),

	LinkToInstance: (self: Janitor, Object: Instance, allowMultiple: boolean?) -> RBXScriptConnection,
	LinkToInstances: (self: Janitor, ...Instance) -> Janitor,
}, {} :: {__call: (self: Janitor) -> ()}))
type Private = typeof(setmetatable({} :: {
	CurrentlyCleaning: boolean,
	SuppressInstanceReDestroy: boolean,
	UnsafeThreadCleanup: boolean,

	-- Private
	-- Packed parallel storage: slot N of `Objects` holds the tracked object,
	-- byte N - 1 of `Tags` holds its disposal tag. `MethodNames` is sparse and
	-- only populated for TAG_CUSTOM slots. `IndexToSlot`/`SlotToIndex` service
	-- the named-index API with O(1) swap-removal.
	Objects: {any},
	Tags: buffer,
	TagsCapacity: number,
	Size: number,
	IndexToSlot: {[any]: number},
	SlotToIndex: {[number]: any},
	MethodNames: {[number]: BooleanOrString},

	Add: <T>(self: Private, object: T, methodName: BooleanOrString?, index: any?) -> T,
	AddObject: <T, A...>(
		self: Private,
		constructor: {new: (A...) -> T},
		methodName: BooleanOrString?,
		index: any?,
		A...
	) -> T,
	AddPromise: <T...>(self: Private, promiseObject: Promise<T...>, index: unknown?) -> Promise<T...>,

	Remove: (self: Private, index: any) -> Private,
	RemoveNoClean: (self: Private, index: any) -> Private,

	RemoveList: (self: Private, ...any) -> Private,
	RemoveListNoClean: (self: Private, ...any) -> Private,

	Get: (self: Private, index: any) -> any?,
	GetAll: (self: Private) -> {[any]: any},

	Cleanup: (self: Private) -> (),
	Destroy: (self: Private) -> (),

	LinkToInstance: (self: Private, object: Instance, allowMultiple: boolean?) -> RBXScriptConnection,
	LinkToInstances: (self: Private, ...Instance) -> Private,
}, {} :: {__call: (self: Private) -> ()}))
type Static = {
	ClassName: "Janitor",

	CurrentlyCleaning: boolean,
	SuppressInstanceReDestroy: boolean,
	UnsafeThreadCleanup: boolean,

	new: () -> Janitor,
	Is: (object: any) -> boolean,
	instanceof: (object: any) -> boolean,
}
type PrivateStatic = Static & {
	__call: (self: Private) -> (),
	__tostring: (self: Private) -> string,
}

--[=[
	Janitor is a light-weight, flexible object for cleaning up connections,
	instances, or anything. This implementation covers all use cases, as it
	doesn't force you to rely on naive typechecking to guess how an instance
	should be cleaned up. Instead, the developer may specify any behavior for
	any object.

	This is the fastest OOP library on Roblox of its kind on both X86-64 as
	well as ARM64.

	@class Janitor
]=]
local Janitor = {} :: Janitor & Static
local Private = Janitor :: Private & PrivateStatic
Janitor.ClassName = "Janitor"
Janitor.CurrentlyCleaning = true
Janitor.SuppressInstanceReDestroy = false
Janitor.UnsafeThreadCleanup = false
(Janitor :: any).__index = Janitor

--[=[
	Whether or not the Janitor is currently cleaning up.
	@readonly
	@prop CurrentlyCleaning boolean
	@within Janitor
]=]
--[=[
	Whether or not you want to suppress the re-destroying of instances. Default
	is false, which is the original behavior.

	@since 1.15.4
	@prop SuppressInstanceReDestroy boolean
	@within Janitor
]=]
--[=[
	Whether or not to use the unsafe fast defer function for cleaning up
	threads. This might be able to throw, so be careful. If you're getting any
	thread related errors, chances are it is this.

	@since 1.18.0
	@prop UnsafeThreadCleanup boolean
	@within Janitor
]=]

local TYPE_DEFAULTS: {[string]: BooleanOrString} = {
	["function"] = true;
	thread = true;
	RBXScriptConnection = "Disconnect";
}

-- Internal storage is pooled and recycled on `Destroy`, so in steady state a
-- create -> add -> cleanup -> destroy cycle performs zero heap allocations and
-- reuses warm array/buffer capacity. Parallel arrays are used for the pool
-- itself so that pushing and popping pool entries allocates nothing either.
local STORE_POOL_CAPACITY = 64

local currentPoolSize = 0
local poolObjects = table.create(STORE_POOL_CAPACITY) :: {{any}}
local poolTags = table.create(STORE_POOL_CAPACITY) :: {buffer}
local poolTagsCapacities = table.create(STORE_POOL_CAPACITY) :: {number}
local poolIndexToSlot = table.create(STORE_POOL_CAPACITY) :: {{[any]: number}}
local poolSlotToIndex = table.create(STORE_POOL_CAPACITY) :: {{[number]: any}}
local poolMethodNames = table.create(STORE_POOL_CAPACITY) :: {{[number]: BooleanOrString}}

--[=[
	Instantiates a new Janitor object.
	@return Janitor
]=]
function Janitor.new(): Janitor
	local self: Private = setmetatable({
		CurrentlyCleaning = false;
	} :: any, Janitor)

	local storePoolSize = currentPoolSize
	if storePoolSize > 0 then
		currentPoolSize = storePoolSize - 1
		self.Objects = poolObjects[storePoolSize]
		poolObjects[storePoolSize] = nil
		self.Tags = poolTags[storePoolSize]
		poolTags[storePoolSize] = nil
		self.TagsCapacity = poolTagsCapacities[storePoolSize]
		poolTagsCapacities[storePoolSize] = nil
		self.IndexToSlot = poolIndexToSlot[storePoolSize]
		poolIndexToSlot[storePoolSize] = nil
		self.SlotToIndex = poolSlotToIndex[storePoolSize]
		poolSlotToIndex[storePoolSize] = nil
		self.MethodNames = poolMethodNames[storePoolSize]
		poolMethodNames[storePoolSize] = nil
	else
		self.Objects = {}
		self.Tags = buffer.create(INITIAL_TAGS_CAPACITY)
		self.TagsCapacity = INITIAL_TAGS_CAPACITY
		self.IndexToSlot = {}
		self.SlotToIndex = {}
		self.MethodNames = {}
	end

	self.Size = 0
	return self :: never
end

--[=[
	Determines if the passed object is a Janitor. This checks the metatable
	directly.

	@param object unknown -- The object you are checking.
	@return boolean -- `true` if `object` is a Janitor.
]=]
function Janitor.Is(object: any): boolean
	return type(object) == "table" and getmetatable(object) == Janitor
end

--[=[
	An alias for [Janitor.Is]. This is intended for roblox-ts support.

	@function instanceof
	@within Janitor

	@param object unknown -- The object you are checking.
	@return boolean -- `true` if `object` is a Janitor.
]=]
Janitor.instanceof = Janitor.Is

local Destroy = game.Destroy

local function GrowTags(self: Private, size: number): ()
	local tagsCapacity = self.TagsCapacity
	repeat
		tagsCapacity *= 2
	until tagsCapacity >= size

	local newTags = buffer.create(tagsCapacity)
	buffer.copy(newTags, 0, self.Tags, 0, size - 1)
	self.Tags = newTags
	self.TagsCapacity = tagsCapacity
end

-- Detaches a slot from storage and returns its disposal information without
-- running the disposal. The hole is filled by swapping the last slot into it
-- (O(1)), keeping the array dense so cleanup never has to skip holes. All
-- bookkeeping (index maps, method names) is patched before any user code can
-- observe the storage again.
local function ExtractSlot(self: Private, slot: number): (any, number, BooleanOrString?)
	local objects = self.Objects
	local tags = self.Tags
	local slotToIndex = self.SlotToIndex
	local methodNames = self.MethodNames
	local size = self.Size

	local object = objects[slot]
	local tag = buffer.readu8(tags, slot - 1)
	local methodName = methodNames[slot]
	if methodName ~= nil then
		methodNames[slot] = nil
	end

	local ownIndex = slotToIndex[slot]
	if ownIndex ~= nil then
		slotToIndex[slot] = nil
		self.IndexToSlot[ownIndex] = nil
	end

	if slot ~= size then
		objects[slot] = objects[size]
		buffer.writeu8(tags, slot - 1, buffer.readu8(tags, size - 1))

		local movedMethodName = methodNames[size]
		if movedMethodName ~= nil then
			methodNames[size] = nil
			methodNames[slot] = movedMethodName
		end

		local movedIndex = slotToIndex[size]
		if movedIndex ~= nil then
			slotToIndex[size] = nil
			slotToIndex[slot] = movedIndex
			self.IndexToSlot[movedIndex] = slot
		end
	end

	objects[size] = nil
	self.Size = size - 1
	return object, tag, methodName
end

local function DisposeObject(self: Private, object: any, tag: number, methodName: BooleanOrString?): ()
	if tag == TAG_CALL then
		object()
	elseif tag == TAG_DESTROY then
		local destroy = object.Destroy :: (self: unknown) -> ()
		if destroy then
			destroy(object)
		end
	elseif tag == TAG_DISCONNECT then
		local disconnect = object.Disconnect :: (self: unknown) -> ()
		if disconnect then
			disconnect(object)
		end
	elseif tag == TAG_DESTROY_INSTANCE then
		if self.SuppressInstanceReDestroy then
			pcall(Destroy, object)
		else
			object:Destroy()
		end
	elseif tag == TAG_THREAD then
		local status = coroutine.status(object)
		if status == "suspended" then
			task.cancel(object)
		elseif status ~= "dead" then
			-- Cancelling a thread from within itself (or within a thread it is
			-- currently resuming) would throw, so the cancellation is deferred.
			if self.UnsafeThreadCleanup then
				FastDefer(task.cancel, object)
			else
				task.defer(task.cancel, object)
			end
		end
	else
		local objectMethod = (object :: never)[methodName] :: (object: unknown) -> ()
		if objectMethod then
			objectMethod(object)
		end
	end
end

@native
local function Remove(self: Private, index: any): Janitor
	local slot = self.IndexToSlot[index]
	if slot then
		local object, tag, methodName = ExtractSlot(self, slot)
		DisposeObject(self, object, tag, methodName)
	end

	return self :: Janitor
end

@native
local function Add<T>(self: Private, object: T, methodName: BooleanOrString?, index: any?): T
	if index ~= nil then
		local previousSlot = self.IndexToSlot[index]
		if previousSlot then
			local previousObject, previousTag, previousMethodName = ExtractSlot(self, previousSlot)
			DisposeObject(self, previousObject, previousTag, previousMethodName)
		end
	end

	local tag: number
	local newMethodName: BooleanOrString
	local typeOf = type(object)

	if typeOf == "function" or typeOf == "thread" then
		newMethodName = methodName or true
		if newMethodName == true then
			tag = if typeOf == "function" then TAG_CALL else TAG_THREAD
		else
			warn(string.format(INVALID_METHOD_NAME, typeOf, tostring(newMethodName), debug.traceback(nil, 2)))
			tag = TAG_CUSTOM
		end
	else
		local robloxType = if typeOf == "userdata" then typeof(object) else typeOf
		newMethodName = methodName or TYPE_DEFAULTS[robloxType] or "Destroy"
		if not (object :: any)[newMethodName] then
			warn(
				string.format(
					METHOD_NOT_FOUND_ERROR,
					tostring(object),
					tostring(newMethodName),
					debug.traceback(nil, 2)
				)
			)
		end

		if newMethodName == "Destroy" then
			tag = if robloxType == "Instance" then TAG_DESTROY_INSTANCE else TAG_DESTROY
		elseif newMethodName == "Disconnect" then
			tag = TAG_DISCONNECT
		else
			tag = TAG_CUSTOM
		end
	end

	local size = self.Size + 1
	self.Size = size
	if size > self.TagsCapacity then
		GrowTags(self, size)
	end

	self.Objects[size] = object
	buffer.writeu8(self.Tags, size - 1, tag)
	if tag == TAG_CUSTOM then
		self.MethodNames[size] = newMethodName
	end

	if index ~= nil then
		self.IndexToSlot[index] = size
		self.SlotToIndex[size] = index
	end

	return object
end

--[=[
	Adds an `object` to Janitor for later cleanup, where `methodName` is the
	key of the method within `object` which should be called at cleanup time.
	If the `methodName` is `true` the `object` itself will be called if it's a
	function or have `task.cancel` called on it if it is a thread. If passed an
	index it will occupy a namespace which can be `Remove()`d or overwritten.
	Returns the `object`.

	:::info Note
	Objects not given an explicit `methodName` will be passed into the `typeof`
	function for a very naive typecheck. RBXConnections will be assigned to
	"Disconnect", functions and threads will be assigned to `true`, and
	everything else will default to "Destroy". Not recommended, but hey, you do
	you.
	:::

	### Luau:

	```lua
	local Workspace = game:GetService("Workspace")
	local TweenService = game:GetService("TweenService")

	local obliterator = Janitor.new()
	local part = Workspace:FindFirstChild("Part") :: Part

	-- Queue the Part to be Destroyed at Cleanup time
	obliterator:Add(part, "Destroy")

	-- Queue function to be called with `true` methodName
	obliterator:Add(print, true)

	-- Close a thread.
	obliterator:Add(task.defer(function()
		while true do
			print("Running!")
			task.wait(0.5)
		end
	end), true)

	-- This implementation allows you to specify behavior for any object
	obliterator:Add(TweenService:Create(part, TweenInfo.new(1), {Size = Vector3.one}), "Cancel")

	-- By passing an index, the object will occupy a namespace
	-- If "CurrentTween" already exists, it will call :Remove("CurrentTween") before writing
	obliterator:Add(TweenService:Create(part, TweenInfo.new(1), {Size = Vector3.one}), "Destroy", "CurrentTween")
	```

	### TypeScript:

	```ts
	import { Workspace, TweenService } from "@rbxts/services";
	import { Janitor } from "@rbxts/janitor";

	const obliterator = new Janitor<{ CurrentTween: Tween }>();
	const part = Workspace.FindFirstChild("Part") as Part;

	// Queue the part to be Destroyed at Cleanup time
	obliterator.Add(part, "Destroy");

	// Queue function to be called with `true` methodName
	obliterator.Add(print, true);

	// Close a thread.
	obliterator.Add(task.defer(() => {
		while (true) {
			print("Running!");
			task.wait(0.5);
		}
	}), true);

	// This implementation allows you to specify behavior for any object
	obliterator.Add(TweenService.Create(part, new TweenInfo(1), { Size: Vector3.one }), "Cancel");

	// By passing an index, the object will occupy a namespace
	// If "CurrentTween" already exists, it will call :Remove("CurrentTween") before writing
	obliterator.Add(TweenService.Create(part, new TweenInfo(1), { Size: Vector3.one }), "Destroy", "CurrentTween");
	```

	@method Add
	@within Janitor

	@param object T -- The object you want to clean up.
	@param methodName? boolean | string -- The name of the method that will be used to clean up. If not passed, it will first check if the object's type exists in TypeDefaults, and if that doesn't exist, it assumes `Destroy`.
	@param index? unknown -- The index that can be used to clean up the object manually.
	@return T -- The object that was passed as the first argument.
]=]
Private.Add = Add

--[=[
	Constructs an object for you and adds it to the Janitor. It's really just
	shorthand for `Janitor:Add(object.new(), methodName, index)`.

	### Luau:

	```lua
	local obliterator = Janitor.new()
	local subObliterator = obliterator:AddObject(Janitor, "Destroy")
	-- subObliterator is another Janitor!
	```

	### TypeScript:

	```ts
	import { Janitor } from "@rbxts/janitor";

	const obliterator = new Janitor();
	const subObliterator = obliterator.AddObject(Janitor, "Destroy");
	```

	@since v1.16.0
	@param constructor {new: (A...) -> T} -- The constructor for the object you want to add to the Janitor.
	@param methodName? boolean | string -- The name of the method that will be used to clean up. If not passed, it will first check if the object's type exists in TypeDefaults, and if that doesn't exist, it assumes `Destroy`.
	@param index? unknown -- The index that can be used to clean up the object manually.
	@param ... A... -- The arguments that will be passed to the constructor.
	@return T -- The object that was passed as the first argument.
]=]
function Janitor:AddObject<T, A...>(constructor: {new: (A...) -> T}, methodName: BooleanOrString?, index: any?, ...: A...): T
	return Add(self :: Private, constructor.new(...), methodName, index)
end

local function Get(self: Private, index: any): any?
	local slot = self.IndexToSlot[index]
	return if slot then self.Objects[slot] else nil
end

--[=[
	Gets whatever object is stored with the given index, if it exists. This was
	added since Maid allows getting the task using `__index`.

	### Luau:

	```lua
	local obliterator = Janitor.new()
	obliterator:Add(Workspace.Baseplate, "Destroy", "Baseplate")
	print(obliterator:Get("Baseplate")) -- Returns Baseplate.
	```

	### TypeScript:

	```ts
	import { Workspace } from "@rbxts/services";
	import { Janitor } from "@rbxts/janitor";

	const obliterator = new Janitor<{ Baseplate: Part }>();
	obliterator.Add(Workspace.FindFirstChild("Baseplate") as Part, "Destroy", "Baseplate");
	print(obliterator.Get("Baseplate")); // Returns Baseplate.
	```

	@method Get
	@within Janitor

	@param index unknown -- The index that the object is stored under.
	@return unknown? -- This will return the object if it is found, but it won't return anything if it doesn't exist.
]=]
Private.Get = Get

--[=[
	Adds a [Promise](https://github.com/evaera/roblox-lua-promise) to the
	Janitor. If the Janitor is cleaned up and the Promise is not completed, the
	Promise will be cancelled.

	### Luau:

	```lua
	local obliterator = Janitor.new()
	obliterator:AddPromise(Promise.delay(3)):andThenCall(print, "Finished!"):catch(warn)
	task.wait(1)
	obliterator:Cleanup()
	```

	### TypeScript:

	```ts
	import { Janitor } from "@rbxts/janitor";

	const obliterator = new Janitor();
	obliterator.AddPromise(Promise.delay(3)).andThenCall(print, "Finished!").catch(warn);
	task.wait(1);
	obliterator.Cleanup();
	```

	@error NotAPromiseError -- Thrown if the promise is not a Promise.

	@param promiseObject Promise -- The promise you want to add to the Janitor.
	@param index? unknown -- The index that can be used to clean up the object manually.
	@return Promise
]=]
function Janitor:AddPromise<T...>(promiseObject: Promise<T...>, index: unknown?): Promise<T...>
	if not Promise then
		return promiseObject
	end

	if not Promise.is(promiseObject) then
		error(string.format(NOT_A_PROMISE, typeof(promiseObject), tostring(promiseObject), debug.traceback(nil, 2)))
	end

	if promiseObject:getStatus() ~= Promise.Status.Started then
		return promiseObject
	end

	local uniqueId = index
	if uniqueId == nil then
		uniqueId = newproxy(false)
	end

	local newPromise = Add(self :: Private, Promise.new(function(resolve, _, onCancel)
		if onCancel(function()
			promiseObject:cancel()
		end) then
			return
		end

		resolve(promiseObject)
	end), "cancel", uniqueId)

	newPromise:finally(function()
		if Get(self :: Private, uniqueId) == newPromise then
			Remove(self :: Private, uniqueId)
		end
	end)

	return newPromise :: never
end

--[=[
	Cleans up whatever `Object` was set to this namespace by the 3rd parameter of [Janitor.Add](#Add).

	### Luau:

	```lua
	local obliterator = Janitor.new()
	obliterator:Add(workspace.Baseplate, "Destroy", "Baseplate")
	obliterator:Remove("Baseplate")
	```

	### TypeScript:

	```ts
	import { Workspace } from "@rbxts/services";
	import { Janitor } from "@rbxts/janitor";

	const obliterator = new Janitor<{ Baseplate: Part }>();
	obliterator.Add(Workspace.FindFirstChild("Baseplate") as Part, "Destroy", "Baseplate");
	obliterator.Remove("Baseplate");
	```

	@method Remove
	@within Janitor

	@param index unknown -- The index you want to remove.
	@return Janitor
]=]
Private.Remove = Remove

--[=[
	Removes an object from the Janitor without running a cleanup.

	### Luau

	```lua
	local obliterator = Janitor.new()
	obliterator:Add(function()
		print("Removed!")
	end, true, "Function")

	obliterator:RemoveNoClean("Function") -- Does not print.
	```

	### TypeScript:

	```ts
	import { Janitor } from "@rbxts/janitor";

	const obliterator = new Janitor<{ Function: () => void }>();
	obliterator.Add(() => print("Removed!"), true, "Function");

	obliterator.RemoveNoClean("Function"); // Does not print.
	```

	@method RemoveNoClean
	@within Janitor

	@since v1.15.0
	@param index unknown -- The index you are removing.
	@return Janitor
]=]
function Private:RemoveNoClean(index: any): Janitor
	local slot = self.IndexToSlot[index]
	if slot then
		ExtractSlot(self, slot)
	end

	return self :: Janitor
end

--[=[
	Cleans up multiple objects at once.

	### Luau:

	```lua
	local obliterator = Janitor.new()
	obliterator:Add(function()
		print("Removed One")
	end, true, "One")

	obliterator:Add(function()
		print("Removed Two")
	end, true, "Two")

	obliterator:Add(function()
		print("Removed Three")
	end, true, "Three")

	obliterator:RemoveList("One", "Two", "Three") -- Prints "Removed One", "Removed Two", and "Removed Three"
	```

	### TypeScript:

	```ts
	import { Janitor } from "@rbxts/janitor";

	type NoOp = () => void

	const obliterator = new Janitor<{ One: NoOp, Two: NoOp, Three: NoOp }>();
	obliterator.Add(() => print("Removed One"), true, "One");
	obliterator.Add(() => print("Removed Two"), true, "Two");
	obliterator.Add(() => print("Removed Three"), true, "Three");

	obliterator.RemoveList("One", "Two", "Three"); // Prints "Removed One", "Removed Two", and "Removed Three"
	```

	@since v1.14.0
	@param ... unknown -- The indices you want to remove.
	@return Janitor
]=]
function Janitor:RemoveList(...: any): Janitor
	local length = select("#", ...)
	if length == 1 then
		return Remove(self :: Private, ...)
	end

	if length == 2 then
		local indexA, indexB = ...
		Remove(self :: Private, indexA)
		Remove(self :: Private, indexB)
		return self
	end

	if length == 3 then
		local indexA, indexB, indexC = ...
		Remove(self :: Private, indexA)
		Remove(self :: Private, indexB)
		Remove(self :: Private, indexC)
		return self
	end

	for selectIndex = 1, length do
		local index = (select(selectIndex, ...))
		Remove(self :: Private, index)
	end

	return self
end

--[=[
	Cleans up multiple objects at once without running their cleanup.

	### Luau:

	```lua
	local obliterator = Janitor.new()
	obliterator:Add(function()
		print("Removed One")
	end, true, "One")

	obliterator:Add(function()
		print("Removed Two")
	end, true, "Two")

	obliterator:Add(function()
		print("Removed Three")
	end, true, "Three")

	obliterator:RemoveListNoClean("One", "Two", "Three") -- Nothing is printed.
	```

	### TypeScript:

	```ts
	import { Janitor } from "@rbxts/janitor";

	type NoOperation = () => void

	const obliterator = new Janitor<{ One: NoOperation, Two: NoOperation, Three: NoOperation }>();
	obliterator.Add(() => print("Removed One"), true, "One");
	obliterator.Add(() => print("Removed Two"), true, "Two");
	obliterator.Add(() => print("Removed Three"), true, "Three");

	obliterator.RemoveListNoClean("One", "Two", "Three"); // Nothing is printed.
	```

	@since v1.15.0
	@param ... unknown -- The indices you want to remove.
	@return Janitor
]=]
function Janitor:RemoveListNoClean(...: any): Janitor
	local this = self :: Private
	local length = select("#", ...)
	if length == 1 then
		local indexA = ...
		local slotA = this.IndexToSlot[indexA]
		if slotA then
			ExtractSlot(this, slotA)
		end
		return self
	end

	if length == 2 then
		local indexA, indexB = ...
		local slotA = this.IndexToSlot[indexA]
		if slotA then
			ExtractSlot(this, slotA)
		end
		local slotB = this.IndexToSlot[indexB]
		if slotB then
			ExtractSlot(this, slotB)
		end
		return self
	end

	if length == 3 then
		local indexA, indexB, indexC = ...
		local slotA = this.IndexToSlot[indexA]
		if slotA then
			ExtractSlot(this, slotA)
		end
		local slotB = this.IndexToSlot[indexB]
		if slotB then
			ExtractSlot(this, slotB)
		end
		local slotC = this.IndexToSlot[indexC]
		if slotC then
			ExtractSlot(this, slotC)
		end
		return self
	end

	for selectIndex = 1, length do
		local index = (select(selectIndex, ...))
		local slot = this.IndexToSlot[index]
		if slot then
			ExtractSlot(this, slot)
		end
	end

	return self
end

--[=[
	Returns a frozen copy of the Janitor's indices.

	### Luau:

	```lua
	local obliterator = Janitor.new()
	obliterator:Add(Workspace.Baseplate, "Destroy", "Baseplate")
	print(obliterator:GetAll().Baseplate) -- Prints Baseplate.
	```

	### TypeScript:

	```ts
	import { Workspace } from "@rbxts/services";
	import { Janitor } from "@rbxts/janitor";

	const obliterator = new Janitor<{ Baseplate: Part }>();
	obliterator.Add(Workspace.FindFirstChild("Baseplate") as Part, "Destroy", "Baseplate");
	print(obliterator.GetAll().Baseplate); // Prints Baseplate.
	```

	@since v1.15.1
	@return {[any]: any}
]=]
function Janitor:GetAll(): {[any]: any}
	local this = self :: Private
	local objects = this.Objects

	local all: {[any]: any} = {}
	for index, slot in this.IndexToSlot do
		all[index] = objects[slot]
	end

	return table.freeze(all)
end

--[=[
	Calls each object's `methodName` (or calls the object if
	`methodName == true`) and removes them from the Janitor. Also clears the
	namespace. This function is also called when you call a Janitor object (so
	it can be used as a destructor callback).

	### Luau:

	```lua
	obliterator:Cleanup() -- Valid.
	obliterator() -- Also valid.
	```

	### TypeScript:

	```ts
	obliterator.Cleanup()
	// TypeScript version doesn't support the __call method of cleaning.
	```

	@method Cleanup
	@within Janitor
]=]
@native
local function Cleanup(self: Private): ()
	if not self.CurrentlyCleaning then
		self.CurrentlyCleaning = true

		local suppressInstanceReDestroy = self.SuppressInstanceReDestroy
		local unsafeThreadCleanup = self.UnsafeThreadCleanup

		local objects = self.Objects
		local methodNames = self.MethodNames

		-- Disposal runs in LIFO order (reverse of insertion), popping from the
		-- end so that user code running inside a disposal can safely Add or
		-- Remove. `Size` and `Tags` are re-read every iteration because such
		-- reentrant calls can change them.
		local size = self.Size
		while size > 0 do
			local object = objects[size]
			local tag = buffer.readu8(self.Tags, size - 1)
			objects[size] = nil
			self.Size = size - 1

			if tag == TAG_CALL then
				object()
			elseif tag == TAG_DESTROY then
				local destroy = object.Destroy :: (self: unknown) -> ()
				if destroy then
					destroy(object)
				end
			elseif tag == TAG_DISCONNECT then
				local disconnect = object.Disconnect :: (self: unknown) -> ()
				if disconnect then
					disconnect(object)
				end
			elseif tag == TAG_DESTROY_INSTANCE then
				if suppressInstanceReDestroy then
					pcall(Destroy, object)
				else
					object:Destroy()
				end
			elseif tag == TAG_THREAD then
				local status = coroutine.status(object)
				if status == "suspended" then
					task.cancel(object)
				elseif status ~= "dead" then
					if unsafeThreadCleanup then
						FastDefer(task.cancel, object)
					else
						task.defer(task.cancel, object)
					end
				end
			else
				local methodName = methodNames[size]
				methodNames[size] = nil
				local objectMethod = (object :: never)[methodName] :: (object: unknown) -> ()
				if objectMethod then
					objectMethod(object)
				end
			end

			size = self.Size
		end

		table.clear(self.IndexToSlot)
		table.clear(self.SlotToIndex)
		self.CurrentlyCleaning = false
	end
end
Private.Cleanup = Cleanup

--[=[
	Calls [Janitor.Cleanup](#Cleanup) and renders the Janitor unusable.

	:::warning Metatable Removal
	Running this will make any further attempts to call a method of Janitor
	error.
	:::
]=]
function Janitor:Destroy(): ()
	local this = self :: Private
	Cleanup(this)

	local storePoolSize = currentPoolSize
	if storePoolSize < STORE_POOL_CAPACITY then
		storePoolSize += 1
		currentPoolSize = storePoolSize
		poolObjects[storePoolSize] = this.Objects
		poolTags[storePoolSize] = this.Tags
		poolTagsCapacities[storePoolSize] = this.TagsCapacity
		poolIndexToSlot[storePoolSize] = this.IndexToSlot
		poolSlotToIndex[storePoolSize] = this.SlotToIndex
		poolMethodNames[storePoolSize] = this.MethodNames
	end

	table.clear(self :: never)
	setmetatable(self :: any, nil)
end

Private.__call = Cleanup

local function LinkToInstance(self: Private, object: Instance, allowMultiple: boolean?): RBXScriptConnection
	local indexToUse = if allowMultiple then newproxy(false) else LinkToInstanceIndex

	return Add(self, object.Destroying:Connect(function()
		Cleanup(self)
	end), "Disconnect", indexToUse)
end

--[=[
	"Links" this Janitor to an Instance, such that the Janitor will `Cleanup`
	when the Instance is `Destroy()`d and garbage collected. A Janitor may only
	be linked to one instance at a time, unless `allowMultiple` is true. When
	called with a truthy `allowMultiple` parameter, the Janitor will "link" the
	Instance without overwriting any previous links, and will also not be
	overwritable. When called with a falsy `allowMultiple` parameter, the
	Janitor will overwrite the previous link which was also called with a falsy
	`allowMultiple` parameter, if applicable.

	### Luau:

	```lua
	local obliterator = Janitor.new()

	obliterator:Add(function()
		print("Cleaning up!")
	end, true)

	do
		local folder = Instance.new("Folder")
		obliterator:LinkToInstance(folder)
		folder:Destroy()
	end
	```

	### TypeScript:

	```ts
	import { Janitor } from "@rbxts/janitor";

	const obliterator = new Janitor();
	obliterator.Add(() => print("Cleaning up!"), true);

	{
		const folder = new Instance("Folder");
		obliterator.LinkToInstance(folder, false);
		folder.Destroy();
	}
	```

	@method LinkToInstance
	@within Janitor

	@param object Instance -- The instance you want to link the Janitor to.
	@param allowMultiple? boolean -- Whether or not to allow multiple links on the same Janitor.
	@return RBXScriptConnection -- A RBXScriptConnection that can be disconnected to prevent the cleanup of LinkToInstance.
]=]
Private.LinkToInstance = LinkToInstance;

(Janitor :: never).LegacyLinkToInstance = LinkToInstance

--[=[
	Links several instances to a new Janitor, which is then returned.

	@param ... Instance -- All the Instances you want linked.
	@return Janitor -- A new Janitor that can be used to manually disconnect all LinkToInstances.
]=]
function Janitor:LinkToInstances(...: Instance): Janitor
	local manualCleanup = Janitor.new()
	for index = 1, select("#", ...) do
		local object = (select(index, ...))
		if typeof(object) ~= "Instance" then
			continue
		end

		manualCleanup:Add(LinkToInstance(self :: Private, object, true), "Disconnect")
	end

	return manualCleanup
end

function Private:__tostring()
	return "Janitor"
end

return Janitor :: Static
