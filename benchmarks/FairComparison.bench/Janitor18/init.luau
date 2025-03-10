--!optimize 2
--!strict

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

	[any]: BooleanOrString,

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

local Janitor = {} :: Janitor & Static
local Private = Janitor :: Private & PrivateStatic
Janitor.ClassName = "Janitor"
Janitor.CurrentlyCleaning = true
Janitor.SuppressInstanceReDestroy = false
Janitor.UnsafeThreadCleanup = false;
(Janitor :: any).__index = Janitor

local Janitors = setmetatable({} :: {[Private]: {[any]: any}}, {__mode = "ks"})

local TYPE_DEFAULTS = {
	["function"] = true;
	thread = true;
	RBXScriptConnection = "Disconnect";
}

function Janitor.new(): Janitor
	return setmetatable({
		CurrentlyCleaning = false;
	}, Janitor) :: never
end

function Janitor.Is(object: any): boolean
	return type(object) == "table" and getmetatable(object) == Janitor
end

Janitor.instanceof = Janitor.Is

local function Remove(self: Private, index: any): Janitor
	local this = Janitors[self]

	if this then
		local object = this[index]
		if not object then
			return self
		end

		local methodName = self[object]
		if methodName then
			if methodName == true then
				if type(object) == "function" then
					object()
				else
					local wasCancelled: boolean = nil
					if coroutine.running() ~= object then
						wasCancelled = pcall(function()
							task.cancel(object)
						end)
					end

					if not wasCancelled then
						if self.UnsafeThreadCleanup then
							FastDefer(function()
								task.cancel(object)
							end)
						else
							task.defer(function()
								task.cancel(object)
							end)
						end
					end
				end
			else
				local objectMethod = object[methodName]
				if objectMethod then
					if self.SuppressInstanceReDestroy and methodName == "Destroy" and typeof(object) == "Instance" then
						pcall(objectMethod, object)
					else
						objectMethod(object)
					end
				end
			end

			self[object] = nil
		end

		this[index] = nil
	end

	return self
end

type BooleanOrString = boolean | string

local function Add<T>(self: Private, object: T, methodName: BooleanOrString?, index: any?): T
	if index then
		Remove(self, index)

		local this = Janitors[self]
		if not this then
			this = {}
			Janitors[self] = this
		end

		this[index] = object
	end

	local typeOf = typeof(object)
	local newMethodName = methodName or TYPE_DEFAULTS[typeOf] or "Destroy"

	if typeOf == "function" or typeOf == "thread" then
		if newMethodName ~= true then
			warn(string.format(INVALID_METHOD_NAME, typeOf, tostring(newMethodName), debug.traceback(nil, 2)))
		end
	else
		if not (object :: never)[newMethodName] then
			warn(
				string.format(
					METHOD_NOT_FOUND_ERROR,
					tostring(object),
					tostring(newMethodName),
					debug.traceback(nil, 2)
				)
			)
		end
	end

	self[object] = newMethodName
	return object
end

Private.Add = Add

function Janitor:AddObject<T, A...>(constructor: {new: (A...) -> T}, methodName: BooleanOrString?, index: any?, ...: A...): T
	return Add(self, constructor.new(...), methodName, index)
end

local function Get(self: Private, index: unknown): any?
	local this = Janitors[self]
	return if this then this[index] else nil
end

Janitor.Get = Get

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

	local newPromise = Add(self, Promise.new(function(resolve, _, onCancel)
		if onCancel(function()
			promiseObject:cancel()
		end) then
			return
		end

		resolve(promiseObject)
	end), "cancel", uniqueId)

	newPromise:finally(function()
		if Get(self, uniqueId) == newPromise then
			Remove(self, uniqueId)
		end
	end)

	return newPromise :: never
end

Private.Remove = Remove

function Private:RemoveNoClean(index: any): Janitor
	local this = Janitors[self]

	if this then
		local object = this[index]
		if object then
			self[object] = nil
			this[index] = nil
		end
	end

	return self
end

function Janitor:RemoveList(...: any): Janitor
	local this = Janitors[self]
	if this then
		local length = select("#", ...)
		if length == 1 then
			return Remove(self, ...)
		end
		if length == 2 then
			local indexA, indexB = ...
			Remove(self, indexA)
			Remove(self, indexB)
			return self
		end
		if length == 3 then
			local indexA, indexB, indexC = ...
			Remove(self, indexA)
			Remove(self, indexB)
			Remove(self, indexC)
			return self
		end

		for selectIndex = 1, length do
			local removeObject = select(selectIndex, ...)
			Remove(self, removeObject)
		end
	end

	return self
end

function Janitor:RemoveListNoClean(...: any): Janitor
	local this = Janitors[self]
	if this then
		local length = select("#", ...)
		if length == 1 then
			local indexA = ...
			local object = this[indexA]
			if object then
				self[object] = nil
				this[indexA] = nil
			end
			return self
		end
		if length == 2 then
			local indexA, indexB = ...
			local objectA = this[indexA]
			if objectA then
				self[objectA] = nil
				this[indexA] = nil
			end
			local objectB = this[indexB]
			if objectB then
				self[objectB] = nil
				this[indexB] = nil
			end
			return self
		end
		if length == 3 then
			local indexA, indexB, indexC = ...
			local objectA = this[indexA]
			if objectA then
				self[objectA] = nil
				this[indexA] = nil
			end
			local objectB = this[indexB]
			if objectB then
				self[objectB] = nil
				this[indexB] = nil
			end
			local objectC = this[indexC]
			if objectC then
				self[objectC] = nil
				this[indexC] = nil
			end
			return self
		end

		for selectIndex = 1, length do
			local index = select(selectIndex, ...)
			local object = this[index]
			if object then
				self[object] = nil
				this[index] = nil
			end
		end
	end

	return self
end

function Janitor:GetAll(): {[any]: any}
	local this = Janitors[self]
	return if this then table.freeze(table.clone(this)) else {}
end

local function Cleanup(self: Private): ()
	if not self.CurrentlyCleaning then
		local suppressInstanceReDestroy = self.SuppressInstanceReDestroy
		local unsafeThreadCleanup = self.UnsafeThreadCleanup

		self.CurrentlyCleaning = nil :: never
		self.SuppressInstanceReDestroy = nil :: never
		self.UnsafeThreadCleanup = nil :: never

		local object, methodName = next(self)

		while object and methodName do
			if methodName == true then
				if type(object) == "function" then
					object()
				elseif type(object) == "thread" then
					local wasCancelled: boolean? = nil
					if coroutine.running() ~= object then
						wasCancelled = pcall(function()
							task.cancel(object)
						end)
					end

					if not wasCancelled then
						local toCleanup = object
						if unsafeThreadCleanup then
							FastDefer(function()
								task.cancel(toCleanup)
							end)
						else
							task.defer(function()
								task.cancel(toCleanup)
							end)
						end
					end
				end
			else
				local objectMethod = (object :: never)[methodName] :: (object: unknown) -> ()
				if objectMethod then
					if suppressInstanceReDestroy and methodName == "Destroy" and typeof(object) == "Instance" then
						pcall(objectMethod, object)
					else
						objectMethod(object)
					end
				end
			end

			self[object] = nil
			object, methodName = next(self, object)
		end

		local this = Janitors[self]
		if this then
			table.clear(this)
			Janitors[self] = nil
		end

		self.CurrentlyCleaning = false
		self.SuppressInstanceReDestroy = suppressInstanceReDestroy
		self.UnsafeThreadCleanup = unsafeThreadCleanup
	end
end

Private.Cleanup = Cleanup

function Janitor:Destroy(): ()
	Cleanup(self)
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

Private.LinkToInstance = LinkToInstance;

(Janitor :: never).LegacyLinkToInstance = LinkToInstance

function Janitor:LinkToInstances(...: Instance): Janitor
	local manualCleanup = Janitor.new()
	for index = 1, select("#", ...) do
		local object = select(index, ...)
		if typeof(object) ~= "Instance" then
			continue
		end

		manualCleanup:Add(LinkToInstance(self, object, true), "Disconnect")
	end

	return manualCleanup
end

function Private:__tostring()
	return "Janitor"
end

return Janitor :: Static
