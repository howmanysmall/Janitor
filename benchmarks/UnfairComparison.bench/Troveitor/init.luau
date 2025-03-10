--!optimize 2
--!strict

local RunService = game:GetService("RunService")
local Janitor = require(script.Parent.Janitor18)
local Promise = require(script.Promise)

type ConnectionLike = {
	Connected: boolean,
	Disconnect: (self: ConnectionLike) -> (),
}
type SignalLike = {
	Connect: (self: SignalLike, callback: (...any) -> ...any) -> ConnectionLike,
	Once: (self: SignalLike, callback: (...any) -> ...any) -> ConnectionLike,
}
type PromiseLike = {
	getStatus: (self: PromiseLike) -> string,
	finally: (self: PromiseLike, callback: (...any) -> ...any) -> PromiseLike,
	cancel: (self: PromiseLike) -> (),
}
type Constructable<T, A...> = {new: (A...) -> T} | (A...) -> T
type Destroyable = {
	Destroy: (self: Destroyable) -> (),
}
type DestroyableLowercase = {
	destroy: (self: DestroyableLowercase) -> (),
}
type Disconnectable = {
	Disconnect: (self: Disconnectable) -> (),
}
type DisconnectableLowercase = {
	disconnect: (self: DisconnectableLowercase) -> (),
}

export type Trackable =
	Instance
	| RBXScriptConnection
	| ConnectionLike
	| Promise.TypedPromise<...any>
	| thread
	| ((...any) -> ...any)
	| Destroyable
	| DestroyableLowercase
	| Disconnectable
	| DisconnectableLowercase

export type Trove = {
	Add: <T>(self: Trove, object: T, cleanupMethod: string?) -> T,
	AddPromise: <T...>(self: Trove, promise: Promise.TypedPromise<T...>) -> Promise.TypedPromise<T...>,
	AttachToInstance: (self: Trove, instance: Instance) -> RBXScriptConnection,
	BindToRenderStep: (self: Trove, name: string, priority: number, fn: (dt: number) -> ()) -> (),
	Clean: (self: Trove) -> (),
	Clone: <T>(self: Trove, instance: T & Instance) -> T,
	Connect: (self: Trove, signal: SignalLike | RBXScriptSignal, fn: (...any) -> ...any) -> ConnectionLike,
	Construct: <T, A...>(self: Trove, class: Constructable<T, A...>, A...) -> T,
	Extend: (self: Trove) -> Trove,
	Remove: (self: Trove, object: Trackable) -> boolean,
	WrapClean: (self: Trove) -> () -> (),
	Destroy: (self: Trove) -> (),
}
type Private = {
	Janitor: Janitor.Janitor,

	Add: <T>(self: Private, object: T, cleanupMethod: string?) -> T,
	AddPromise: <T...>(self: Private, promise: Promise.TypedPromise<T...>) -> Promise.TypedPromise<T...>,
	AttachToInstance: (self: Private, instance: Instance) -> RBXScriptConnection,
	BindToRenderStep: (self: Private, name: string, priority: number, fn: (dt: number) -> ()) -> (),
	Clean: (self: Private) -> (),
	Clone: <T>(self: Private, instance: T & Instance) -> T,
	Connect: (self: Private, signal: SignalLike | RBXScriptSignal, fn: (...any) -> ...any) -> ConnectionLike,
	Construct: <T, A...>(self: Private, class: Constructable<T, A...>, A...) -> T,
	Extend: (self: Private) -> Private,
	Remove: (self: Private, object: Trackable) -> boolean,
	WrapClean: (self: Private) -> () -> (),
	Destroy: (self: Private) -> (),
}
type Static = {
	ClassName: "Trove",
	new: () -> Trove,
}

local Trove = {} :: Trove & Static
local Private = Trove :: Private & Static
Trove.ClassName = "Trove";
(Trove :: any).__index = Trove

function Trove.new(): Trove
	return setmetatable({
		Janitor = Janitor.new();
	}, Trove) :: never
end

function Private:Add<T>(object: T, cleanupMethod): T
	return self.Janitor:Add(object, cleanupMethod, object)
end

function Private:AddPromise<T...>(object)
	return self.Janitor:AddPromise(object)
end

function Private:AttachToInstance(object)
	if not object:IsDescendantOf(game) then
		error("instance is not a descendant of the game hierarchy", 2)
	end

	return self.Janitor:LinkToInstance(object, false)
end

function Private:BindToRenderStep(name, priority, callback)
	RunService:BindToRenderStep(name, priority, callback)
	self:Add(function()
		RunService:UnbindFromRenderStep(name)
	end)
end

function Private:Clean()
	self.Janitor:Cleanup()
end

function Private:Clone<T>(instance)
	local object = instance:Clone()
	return self.Janitor:Add(object, "Destroy", object)
end

function Private:Connect(signal, callback)
	return self:Add((signal :: any):Connect(callback))
end

function Private:Construct<T, A...>(class, ...)
	local object = nil
	local t = type(class)
	if t == "table" then
		object = (class :: any).new(...)
	elseif t == "function" then
		object = (class :: any)(...)
	end

	return self:Add(object)
end

function Private:Extend()
	return self:Add(Trove.new()) :: never
end

function Private:Remove(object)
	if self.Janitor:Get(object) == nil then
		return false
	end

	self.Janitor:Remove(object)
	return self.Janitor:Get(object) == nil
end

function Private:Destroy()
	self:Clean()
end

function Private:WrapClean()
	return function()
		self:Clean()
	end
end

return table.freeze(Trove :: Static)
